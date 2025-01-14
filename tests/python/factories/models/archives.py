from dataclasses import dataclass

@dataclass
class Archive:
    name: str
    tags: str
    summary: str
    arcsize: str
    file: str
    title: str
    isnew: str
    pagecount: str
    thumbhash: str