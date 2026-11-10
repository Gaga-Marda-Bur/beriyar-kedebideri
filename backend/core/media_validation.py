"""Validate new uploads only; do not rewrite or revalidate legacy references."""
from contextlib import contextmanager
from pathlib import Path, PurePosixPath
import struct
import warnings
import wave
import zipfile
import zlib

from django.core.exceptions import ValidationError
from django.db import models
from PIL import Image


@contextmanager
def readable(upload, limit):
    if upload.size <= 0 or upload.size > limit:
        raise ValidationError('Fichier vide ou taille maximale dépassée.')
    position = upload.tell()
    try:
        upload.seek(0)
        yield upload
    finally:
        upload.seek(position)


def validate_image(upload, limit=5*1024*1024):
    formats={'.jpg':'JPEG','.jpeg':'JPEG','.png':'PNG','.webp':'WEBP'}
    with readable(upload,limit) as stream:
        try:
            with warnings.catch_warnings():
                warnings.simplefilter('error',Image.DecompressionBombWarning)
                image=Image.open(stream)
                if image.format != formats.get(Path(upload.name).suffix.lower()) or max(image.size)>4096:
                    raise ValueError('Unsupported image')
                image.verify()
                stream.seek(0)
                decoded=Image.open(stream)
                decoded.load()
        except Exception as error:
            raise ValidationError('Image invalide : JPEG, PNG ou WebP, maximum 4096 px.') from error


def validate_audio(upload):
    suffix=Path(upload.name).suffix.lower()
    with readable(upload,20*1024*1024) as stream:
        header=stream.read(64)
        valid=False
        if suffix=='.wav':
            try:
                stream.seek(0)
                with wave.open(stream,'rb') as wav:
                    valid=(wav.getnchannels()>0 and wav.getframerate()>0 and wav.getnframes()>0
                           and len(wav.readframes(1))==wav.getnchannels()*wav.getsampwidth())
            except (wave.Error,EOFError):
                pass
        elif suffix=='.mp3':
            start=0
            if header.startswith(b'ID3') and len(header)>=10:
                tag=header[6:10]
                if all(b<128 for b in tag):
                    start=10+sum(b<<(7*(3-i)) for i,b in enumerate(tag))
                    if header[3]==4 and header[5]&16:start+=10
                else:start=upload.size
            stream.seek(start)
            frame=stream.read(4)
            if len(frame)==4 and frame[0]==255 and frame[1]&224==224:
                version=(frame[1]>>3)&3;layer=(frame[1]>>1)&3
                rate_index=(frame[2]>>2)&3;bitrate_index=frame[2]>>4
                if version in (0,2,3) and layer==1 and rate_index<3 and 0<bitrate_index<15:
                    rates=(44100,48000,32000)
                    rate=rates[rate_index]//(1 if version==3 else 2 if version==2 else 4)
                    bitrates=(32,40,48,56,64,80,96,112,128,160,192,224,256,320) if version==3 else (8,16,24,32,40,48,56,64,80,96,112,128,144,160)
                    length=(144 if version==3 else 72)*bitrates[bitrate_index-1]*1000//rate+((frame[2]>>1)&1)
                    valid=start+length<=upload.size
        elif suffix=='.m4a':
            valid=(len(header)>=12 and header[4:8]==b'ftyp' and header[8:12] in (b'M4A ',b'isom',b'mp42',b'iso2')
                   and valid_bmff(stream,upload.size))
        if not valid:
            raise ValidationError('Audio invalide : MP3, M4A ou WAV attendu (20 Mo maximum).')


def validate_video(upload):
    with readable(upload,50*1024*1024) as stream:
        header=stream.read(64)
        suffix=Path(upload.name).suffix.lower()
        valid=(suffix=='.mp4' and len(header)>=12 and header[4:8]==b'ftyp'
               and header[8:12] in (b'isom',b'iso2',b'mp41',b'mp42',b'avc1')
               and valid_bmff(stream,upload.size))
        valid=valid or (suffix=='.webm' and header.startswith(b'\x1aE\xdf\xa3') and b'webm' in header.lower())
        if not valid:
            raise ValidationError('Vidéo invalide : MP4 ou WebM attendu (50 Mo maximum).')


def valid_bmff(stream,size):
    """Bounded ISO BMFF container check; this is not a codec/antivirus scan."""
    offset=0;boxes=set()
    while offset<size:
        stream.seek(offset)
        header=stream.read(8)
        if len(header)!=8:return False
        length,kind=struct.unpack('>I4s',header)
        minimum=8
        if length==1:
            extended=stream.read(8)
            if len(extended)!=8:return False
            length=struct.unpack('>Q',extended)[0];minimum=16
        if length==0:length=size-offset
        if length<minimum or offset+length>size:return False
        if kind in (b'mdat',b'moov') and length<=minimum:return False
        boxes.add(kind);offset+=length
    return {b'ftyp',b'moov',b'mdat'}<=boxes


def validate_pack(upload):
    with readable(upload,200*1024*1024) as stream:
        try:
            if Path(upload.name).suffix.lower()!='.zip':
                raise ValueError('Extension')
            with zipfile.ZipFile(stream) as archive:
                entries=archive.infolist()
                # Match the existing Flutter extractor's safety limits.
                if len(entries)>5000 or sum(e.file_size for e in entries)>500*1024*1024:
                    raise ValueError('Archive limits')
                for entry in entries:
                    name=entry.orig_filename
                    path=PurePosixPath(name)
                    mode=entry.external_attr>>16
                    if (path.is_absolute() or '..' in path.parts or '\\' in name or '\0' in name
                            or ':' in name or mode & 0o170000 == 0o120000
                            or entry.flag_bits & 1):
                        raise ValueError('Unsafe ZIP member')
                if archive.testzip() is not None:
                    raise ValueError('CRC')
        except (ValueError,zipfile.BadZipFile,RuntimeError,NotImplementedError,OSError,EOFError,zlib.error) as error:
            raise ValidationError('Archive ZIP invalide ou chemin dangereux.') from error


class ValidatedMediaModel(models.Model):
    """Enforce checks for fresh files in both ModelForms and direct ORM saves."""
    class Meta:
        abstract=True

    def validate_uploaded_media(self):
        for field in self._meta.fields:
            if not isinstance(field,models.FileField):
                continue
            upload=getattr(self,field.name)
            if not upload or upload._committed:
                continue
            try:
                if isinstance(field,models.ImageField):
                    validate_image(upload,2*1024*1024 if self._meta.label=='feedback.FeedbackReport' else 5*1024*1024)
                elif self._meta.label=='audio_assets.AudioAsset':
                    validate_audio(upload)
                elif self._meta.label=='offline_packs.LessonPack':
                    validate_pack(upload)
                elif field.name=='video_file':
                    validate_video(upload)
            except ValidationError as error:
                raise ValidationError({field.name:error.messages}) from error

    def clean_fields(self,exclude=None):
        super().clean_fields(exclude=exclude)
        self.validate_uploaded_media()

    def save(self,*args,**kwargs):
        self.validate_uploaded_media()
        return super().save(*args,**kwargs)
