from __future__ import print_function

import os
import sys
import json
import hashlib
import urllib
import boto3

from evernote.api.client import EvernoteClient
import evernote.edam.type.ttypes as Types

en = EvernoteClient(token=os.environ['token'], sandbox=False)

s3 = boto3.client('s3')
noteStore = en.get_note_store()


def get_notebook_by_name(name):
    notebooks = noteStore.listNotebooks()
    return [n for n in notebooks if n.name == name][0]


def file2evernote(filename, data, mimetype, notebook=None, tags=[], title=None):
    print("Creating note for file {0} in notebook {1}".format(filename, notebook))

    guid = get_notebook_by_name(notebook).guid

    if not title:
        title = filename

    resource = Types.Resource()
    resource.data = Types.Data()
    resource.data.body = data
    resource.attributes = Types.ResourceAttributes(fileName=filename, attachment=False)
    resource.mime = mimetype
    hash = hashlib.md5()
    hash.update(resource.data.body)
    attachment = '<en-media type="{0}" hash="{1}" />\n'.format(resource.mime, hash.hexdigest())

    content = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">
<en-note>"""+ attachment +"</en-note>"

    note = Types.Note(title=title, content=content, tagNames=tags, resources=[resource], notebookGuid=guid)
    return noteStore.createNote(note)

def lambda_handler(event, context):
    # Get the object from the event and show its content type
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.unquote_plus(event['Records'][0]['s3']['object']['key'].encode('utf8'))
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        # handle path elements as tags
        file_tags = os.path.dirname(key).split('/')
        # first element is interpreted as notebook name
        notebook = file_tags.pop(0)
        # add static tags configured via lambda environment variables
        tags = file_tags + os.environ['static_tags'].split(',')
        note = file2evernote(os.path.basename(key), response['Body'].read(), response['ContentType'], notebook, tags)

        if os.environ['delete_imported_files'] in ['1', 'true', 'True', 'TRUE']:
            # delete imported object
            s3.delete_object(Bucket=bucket, Key=key)
        else:
            # tag object as imported
            response = s3.put_object_tagging(
                Bucket=bucket,
                Key=key,
                Tagging={'TagSet': [
                    {'Key': 'EvernoteGUID',
                    'Value': note.guid} ]
                }
            )

    except Exception as e:
        print('Error saving object {} from bucket {} in evernote.'.format(key, bucket))
        raise e
