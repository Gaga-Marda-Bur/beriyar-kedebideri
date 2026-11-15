"""Private feedback bytes never receive an anonymous storage URL."""
from django.conf import settings
from django.core.files.storage import Storage, FileSystemStorage, default_storage, storages
from django.urls import reverse
from django.utils.deconstruct import deconstructible


def private_backend():
    # Resolve local location at use time (including isolated tests).
    if (not settings.USE_R2 or settings.STORAGES.get('private',{}).get('BACKEND') ==
            'django.core.files.storage.FileSystemStorage'):
        return FileSystemStorage(location=settings.PRIVATE_MEDIA_ROOT)
    return storages['private']


@deconstructible
class FeedbackAttachmentStorage(Storage):
    def _open(self,name,mode='rb'):
        if private_backend().exists(name):
            return private_backend().open(name,mode)
        # Read-only legacy compatibility, exposed only through the staff route.
        return default_storage.open(name,mode)

    def _save(self,name,content):
        return private_backend().save(name,content)

    def exists(self,name):
        return private_backend().exists(name) or default_storage.exists(name)

    def size(self,name):
        if private_backend().exists(name):
            return private_backend().size(name)
        return default_storage.size(name)

    def url(self,name):
        return reverse('feedback-attachment',kwargs={'name':name})

    def delete(self,name):
        private_backend().delete(name)


@deconstructible
class PrivatePackStorage(Storage):
    """Private storage for non-published offline lesson packs."""

    def _open(self, name, mode='rb'):
        return private_backend().open(name, mode)

    def _save(self, name, content):
        return private_backend().save(name, content)

    def exists(self, name):
        return private_backend().exists(name)

    def size(self, name):
        return private_backend().size(name)

    def url(self, name):
        # Never expose a direct storage or CDN URL for private packs.
        return ''

    def delete(self, name):
        private_backend().delete(name)


@deconstructible
class AudioMediaStorage(FeedbackAttachmentStorage):
    def backend(self,name):
        return private_backend() if name.startswith('feedback/audio/') else default_storage

    def _open(self,name,mode='rb'):
        return self.backend(name).open(name,mode)

    def _save(self,name,content):
        return self.backend(name).save(name,content)

    def exists(self,name):
        return self.backend(name).exists(name)

    def size(self,name):
        return self.backend(name).size(name)

    def url(self,name):
        if name.startswith('feedback/audio/'):
            return reverse('feedback-audio-file',kwargs={'name':name})
        return default_storage.url(name)

    def delete(self,name):
        self.backend(name).delete(name)


def audio_upload_path(instance,filename):
    return ('feedback/audio/' if instance.audio_type=='feedback' else 'audio_assets/files/')+filename
