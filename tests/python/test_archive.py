import unittest
import requests
import redis
import shutil
from utils.utils import generate_archive_id
from factories.archivefactory import ArchiveFactory

class ArchiveAPITestCase(unittest.TestCase):
    def setUp(self):
        self.redis_client = redis.Redis(host='redis', port=6379)
        self.archivefactory = ArchiveFactory

    def tearDown(self):
        shutil.rmtree('/lanraragi/content/test')
        self.redis_client.flushall()

    def test_archives_list(self):
        arcid = "28697b96f0ac5858be2614ed10ca47742c9522fd" #generate_archive_id()
        archive = self.archivefactory.create()
        print(archive.__dict__)
        print(arcid)
        self.redis_client.hset(arcid, mapping=archive.__dict__)

        response = requests.get('http://lanraragi:3000/api/archives')
        data = response.json()
        print(data)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(data[0]["arcid"], arcid)
        self.assertEqual(data[0]["filename"], archive.name)

if __name__ == '__main__':
    unittest.main()