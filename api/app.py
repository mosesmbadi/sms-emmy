
from flask import Flask, request, jsonify, render_template
from flask_sqlalchemy import SQLAlchemy
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import phonenumbers
import os
import csv
import io

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(os.path.abspath(os.path.dirname(__file__)), 'messages.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["200 per day", "50 per hour"]
)

class Message(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    phone_number = db.Column(db.String(20), nullable=False)
    message = db.Column(db.String(200), nullable=False)
    status = db.Column(db.String(20), nullable=False, default='pending')
    error_message = db.Column(db.String(200), nullable=True)

    __table_args__ = (db.UniqueConstraint('phone_number', 'message', name='_phone_message_uc'),)

    def __repr__(self):
        return f'<Message {self.id}>'

def csv_to_json_converter(csv_content, message_template):
    """
    Convert CSV content and message template to JSON format expected by the API
    
    Args:
        csv_content (str): CSV content as string
        message_template (str): Message template with placeholders
        
    Returns:
        dict: JSON object with contacts and message
    """
    try:
        # Parse CSV content
        csv_reader = csv.DictReader(io.StringIO(csv_content))
        contacts = []
        
        for row in csv_reader:
            # Clean up the row data (remove extra spaces)
            contact = {key.strip(): value.strip() for key, value in row.items()}
            
            # Ensure we have at least phone and name
            if 'phone' in contact and contact['phone']:
                # Set default values for missing fields
                if 'name' not in contact or not contact['name']:
                    contact['name'] = 'Customer'
                if 'company' not in contact or not contact['company']:
                    contact['company'] = 'N/A'
                    
                contacts.append(contact)
        
        return {
            'contacts': contacts,
            'message': message_template
        }
    except Exception as e:
        raise ValueError(f"Error processing CSV: {str(e)}")

@app.route('/')
def index():
    """Render the main UI page"""
    return render_template('index.html')

@app.route('/results')
def results():
    """Render the results page"""
    return render_template('results.html')

@app.route('/upload', methods=['POST'])
@limiter.limit("5 per minute")
def upload_and_process():
    """Handle CSV upload and convert to JSON for processing"""
    try:
        # Check if file and message are provided
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
        
        # Read CSV content
        csv_content = csv_file.read().decode('utf-8')
        
        # Convert CSV to JSON format
        json_data = csv_to_json_converter(csv_content, message_template)
        
        # Validate that we have contacts
        if not json_data['contacts']:
            return jsonify({'error': 'No valid contacts found in CSV file'}), 400
        
        # Process the messages using existing logic
        contacts = json_data['contacts']
        message_template = json_data['message']
        
        processed_count = 0
        failed_count = 0
        
        for contact in contacts:
            phone = contact.get('phone')
            message = message_template.format(**contact)

            existing_message = Message.query.filter_by(phone_number=phone, message=message).first()
            if existing_message:
                continue

            if not phone:
                new_message = Message(phone_number="N/A", message=message, status='failed', error_message='Missing phone number')
                db.session.add(new_message)
                failed_count += 1
                continue

            try:
                parsed_number = phonenumbers.parse(phone, None)
                if not phonenumbers.is_valid_number(parsed_number):
                    new_message = Message(phone_number=phone, message=message, status='failed', error_message='Invalid phone number')
                    db.session.add(new_message)
                    failed_count += 1
                    continue
            except phonenumbers.phonenumberutil.NumberParseException as e:
                new_message = Message(phone_number=phone, message=message, status='failed', error_message=str(e))
                db.session.add(new_message)
                failed_count += 1
                continue

            new_message = Message(phone_number=phone, message=message, status='success')
            db.session.add(new_message)
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

        existing_message = Message.query.filter_by(phone_number=phone, message=message).first()
        if existing_message:
            continue

        if not phone:
            new_message = Message(phone_number="N/A", message=message, status='failed', error_message='Missing phone number')
            db.session.add(new_message)
            continue

        try:
            parsed_number = phonenumbers.parse(phone, None)
            if not phonenumbers.is_valid_number(parsed_number):
                new_message = Message(phone_number=phone, message=message, status='failed', error_message='Invalid phone number')
                db.session.add(new_message)
                continue
        except phonenumbers.phonenumberutil.NumberParseException as e:
            new_message = Message(phone_number=phone, message=message, status='failed', error_message=str(e))
            db.session.add(new_message)
            continue

        new_message = Message(phone_number=phone, message=message, status='success')
        db.session.add(new_message)

    db.session.commit()

    return jsonify({'message': 'Messages are being processed.'}), 202

@app.route('/metrics', methods=['GET'])
def metrics():
    messages = Message.query.all()
    output = []
    for message in messages:
        output.append({
            'id': message.id,
            'phone_number': message.phone_number,
            'message': message.message,
            'status': message.status,
            'error_message': message.error_message
        })
    return jsonify({'messages': output})

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=5000)
