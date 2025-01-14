import uuid
import hashlib

def generate_archive_id():
    base_id = uuid.uuid4().hex
    hashid = hashlib.sha1(base_id.encode()).hexdigest()
    
    return hashid