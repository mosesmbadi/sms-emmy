from flask import Flask, request, jsonify, render_template, Response
from flask_sqlalchemy import SQLAlchemy
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
import phonenumbers
import os
import csv
import io
import logging
from datetime import datetime
import time

# 1. Standard Flask App and DB setup
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(os.path.abspath(os.path.dirname(__file__)), 'messages.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# 2. Prometheus metrics endpoint (explicit)
# Exposes default Python/process metrics; Prometheus will scrape /metrics
@app.route('/metrics')
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

# 3. Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
    ]
)
logger = logging.getLogger(__name__)

# 4. Configure Rate Limiter
limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["200 per day", "50 per hour"]
)

# 5. Database Model
class Message(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    phone_number = db.Column(db.String(20), nullable=False)
    message = db.Column(db.String(200), nullable=False)
    status = db.Column(db.String(20), nullable=False, default='pending')
    error_message = db.Column(db.String(200), nullable=True)
    __table_args__ = (db.UniqueConstraint('phone_number', 'message', name='_phone_message_uc'),)

    def __repr__(self):
        return f'<Message {self.id}>'

# 6. Helper function
def csv_to_json_converter(csv_content, message_template):
    try:
        csv_reader = csv.DictReader(io.StringIO(csv_content))
        contacts = []
        for row in csv_reader:
            contact = {key.strip(): value.strip() for key, value in row.items()}
            if 'phone' in contact and contact['phone']:
                if 'name' not in contact or not contact['name']:
                    contact['name'] = 'Customer'
                if 'company' not in contact or not contact['company']:
                    contact['company'] = 'N/A'
                contacts.append(contact)
        return {'contacts': contacts, 'message': message_template}
    except Exception as e:
        raise ValueError(f"Error processing CSV: {str(e)}")

# 7. Application Routes
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/health')
def health():
    start_time = time.time()
    try:
        db.session.execute('SELECT 1')
        total_messages = Message.query.count()
        pending_messages = Message.query.filter_by(status='pending').count()
        response_time = (time.time() - start_time) * 1000
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.utcnow().isoformat(),
            'database': 'connected',
            'version': '1.0.0',
            'stats': {
                'total_messages': total_messages,
                'pending_messages': pending_messages,
                'response_time_ms': round(response_time, 2)
            }
        }), 200
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return jsonify({
            'status': 'unhealthy',
            'timestamp': datetime.utcnow().isoformat(),
            'database': 'disconnected',
            'error': str(e)
        }), 503

@app.route('/results')
def results():
    return render_template('results.html')

@app.route('/monitoring')
def monitoring():
    return render_template('monitoring.html')

@app.route('/upload', methods=['POST'])
@limiter.limit("5 per minute")
def upload_and_process():
    client_ip = request.remote_addr
    logger.info(f"CSV upload request from {client_ip}")
    try:
        if 'csvFile' not in request.files:
            return jsonify({'error': 'No CSV file provided'}), 400
        if 'message' not in request.form:
            return jsonify({'error': 'No message template provided'}), 400
        
        csv_file = request.files['csvFile']
        message_template = request.form['message']
        
        if csv_file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
        if not csv_file.filename.endswith('.csv'):
            return jsonify({'error': 'File must be a CSV file'}), 400
        
        csv_content = csv_file.read().decode('utf-8')
        json_data = csv_to_json_converter(csv_content, message_template)
        
        if not json_data['contacts']:
            return jsonify({'error': 'No valid contacts found in CSV file'}), 400
        
        contacts = json_data['contacts']
        message_template = json_data['message']
        processed_count = 0
        failed_count = 0
        
        for contact in contacts:
            phone = contact.get('phone')
            message = message_template.format(**contact)
            if Message.query.filter_by(phone_number=phone, message=message).first():
                continue
            if not phone:
                db.session.add(Message(phone_number="N/A", message=message, status='failed', error_message='Missing phone number'))
                failed_count += 1
                continue
            try:
                parsed_number = phonenumbers.parse(phone, None)
                if not phonenumbers.is_valid_number(parsed_number):
                    db.session.add(Message(phone_number=phone, message=message, status='failed', error_message='Invalid phone number'))
                    failed_count += 1
                    continue
            except phonenumbers.phonenumberutil.NumberParseException as e:
                db.session.add(Message(phone_number=phone, message=message, status='failed', error_message=str(e)))
                failed_count += 1
                continue
            db.session.add(Message(phone_number=phone, message=message, status='success'))
            processed_count += 1
        db.session.commit()
        return jsonify({
            'message': f'Processing complete. {processed_count} messages processed successfully, {failed_count} failed.',
            'processed': processed_count,
            'failed': failed_count,
            'total_contacts': len(contacts)
        }), 200
    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        return jsonify({'error': f'Unexpected error: {str(e)}'}), 500

@app.route('/messages', methods=['POST'])
@limiter.limit("1 per second")
def create_messages():
    data = request.get_json()
    if not data or 'contacts' not in data or 'message' not in data:
        return jsonify({'error': 'Invalid data'}), 400
    contacts = data['contacts']
    message_template = data['message']
    if not isinstance(contacts, list):
        return jsonify({'error': 'Contacts should be a list'}), 400
    for contact in contacts:
        phone = contact.get('phone')
        message = message_template.format(**contact)
        if Message.query.filter_by(phone_number=phone, message=message).first():
            continue
        if not phone:
            db.session.add(Message(phone_number="N/A", message=message, status='failed', error_message='Missing phone number'))
            continue
        try:
            parsed_number = phonenumbers.parse(phone, None)
            if not phonenumbers.is_valid_number(parsed_number):
                db.session.add(Message(phone_number=phone, message=message, status='failed', error_message='Invalid phone number'))
                continue
        except phonenumbers.phonenumberutil.NumberParseException as e:
            db.session.add(Message(phone_number=phone, message=message, status='failed', error_message=str(e)))
            continue
        db.session.add(Message(phone_number=phone, message=message, status='success'))
    db.session.commit()
    return jsonify({'message': 'Messages are being processed.'}), 202

@app.route('/metrics_summary')
def metrics_summary():
    """Provide a summary of message statuses and recent messages in JSON format."""
    try:
        total_messages = Message.query.count()
        success_count = Message.query.filter_by(status='success').count()
        failed_count = Message.query.filter_by(status='failed').count()
        pending_count = Message.query.filter_by(status='pending').count()
        success_rate = (success_count / total_messages * 100) if total_messages > 0 else 100
        recent_messages = Message.query.order_by(Message.id.desc()).limit(100).all()
        messages_list = [
            {
                'id': msg.id,
                'phone_number': '***' + msg.phone_number[-4:],
                'status': msg.status,
                'error_message': msg.error_message
            }
            for msg in recent_messages
        ]
        return jsonify({
            'timestamp': datetime.utcnow().isoformat(),
            'summary': {
                'total_messages': total_messages,
                'success_count': success_count,
                'failed_count': failed_count,
                'pending_count': pending_count,
                'success_rate_percent': round(success_rate, 2)
            },
            'recent_messages': messages_list
        }), 200
    except Exception as e:
        logger.error(f"Metrics summary endpoint failed: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': 'Could not retrieve metrics summary.',
            'error': str(e)
        }), 500

# 8. Main execution block
if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=5000)
