import factory
import os
import zipfile

from factories.models.archives import Archive

def generate_file(obj):
    logo_path = "/lanraragi/public/img/logo.png"
    content_path = "/lanraragi/content/test"
    
    if not os.path.exists(content_path):
        os.makedirs(content_path)

    zip_path = os.path.join(content_path, f"{obj.name}.zip")

    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        file_name = os.path.basename(logo_path)
        zipf.write(logo_path, file_name)

    return "/home/koyomi"+zip_path

class ArchiveFactory(factory.Factory):
    class Meta:
        model = Archive

    name = factory.Faker("first_name")
    tags = "date_added:1736124197"
    summary = ""
    arcsize = "16532135"
    file = factory.LazyAttribute(lambda p: '/home/koyomi/lanraragi/content/test/{}.zip'.format(p.name))
    title = factory.LazyAttribute(lambda p: p.name)
    isnew = "true"
    pagecount = "30"
    thumbhash = "ec2a0ca3a3da67a9390889f0910fe494241faa9a"

    @factory.post_generation
    def generate_file(obj, create, extracted, **kwargs):
        if not create:
            return

        logo_path = "/lanraragi/public/img/logo.png"
        content_path = "/lanraragi/content/test"
        
        if not os.path.exists(content_path):
            os.makedirs(content_path)

        zip_path = os.path.join(content_path, f"{obj.name}.zip")

        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            file_name = os.path.basename(logo_path)
            zipf.write(logo_path, file_name)

        return "/home/koyomi"+zip_path