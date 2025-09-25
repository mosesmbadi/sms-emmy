
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import phonenumbers
import os

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
