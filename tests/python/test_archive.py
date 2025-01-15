import unittest
import requests
import redis
import shutil
import base64
import os
from utils.utils import generate_archive_id
from factories.archivefactory import ArchiveFactory

class ArchiveAPITestCase(unittest.TestCase):
    def setUp(self):
        self.redis_client = redis.Redis(host='redis', port=6379)
        self.archivefactory = ArchiveFactory

        # Set Apikey
        self.redis_client.select(2)
        self.redis_client.hset("LRR_CONFIG", "apikey", "lanraragi")
        self.redis_client.select(0)

    def tearDown(self):
        if os.path.exists('/lanraragi/content/test'):
            shutil.rmtree('/lanraragi/content/test')
        self.redis_client.flushall()

    def test_archives_list(self):
        arcid = "28697b96f0ac5858be2614ed10ca47742c9522fd" #generate_archive_id()
        archive = self.archivefactory.create()
        self.redis_client.hset(arcid, mapping=archive.__dict__)

        response = requests.get('http://lanraragi:3000/api/archives')
        data = response.json()

        self.assertEqual(response.status_code, 200)
        self.assertEqual(data[0]["arcid"], arcid)
        self.assertEqual(data[0]["filename"], archive.name)

    def test_plugins_list(self):
        bearer = base64.b64encode("lanraragi".encode(encoding='utf-8')).decode('utf-8')
        header = {'accept':'application/json', 'authorization': 'Bearer '+bearer}
        response = requests.get('http://lanraragi:3000/api/plugins/login', headers=header)
        data = response.json()

        self.assertEqual(response.status_code, 200)
        self.assertEqual(data[0]["author"], "Difegue")

if __name__ == '__main__':
    unittest.main()