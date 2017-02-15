# S3 to Evernote

This is an AWS Lambda function importing files uploaded to S3 into Evernote. Each uploaded file will be embedded in a new note with the file name as title.

## Prerequisites

1. An [Evernote Developer token](https://www.evernote.com/api/DeveloperToken.action) for your account
2. An Unix environment with GNU make, Python 2.7, pip and a configured AWS CLI
3. A S3 bucket with files to be uploaded
4. An IAM managed policy called `s3-to-evernote` which grants access to the bucket
  ```json
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Sid": "S3ObjectPermissions",
              "Effect": "Allow",
              "Action": [
                  "s3:DeleteObject",
                  "s3:GetObject",
                  "s3:PutObjectTagging"
              ],
              "Resource": [
                  "arn:aws:s3:::REPLACE_WITH_BUCKET_NAME/*"
              ]
          }
      ]
  }
  ```

## Installation

1. Clone repo
2. Set `EVERNOTE_DEV_TOKEN` in the Makefile, preferably [encrypted](http://docs.aws.amazon.com/lambda/latest/dg/env_variables.html) with [KMS](https://aws.amazon.com/kms/) to protect your token
3. Run `make` to build zip file
4. Run `make deploy` to create Lambda function in AWS account (needs configured AWS CLI)
5. Add an event trigger for created objects (Put) in the Lambda console for your S3 bucket

## Usage

s3-to-evernote expects a certain prefix for uploaded files. You have to use the notebook name as a first path element. Tags are optional.

```
/NotebookName/Tag1/Tag2/TagN/Filename.ext
```

If you want imported files to be deleted on successful import into Evernote set the Lambda environment variable `delete_imported_files` to 1.

## Background

This has been created to automatically import files scanned by a document scanner. Those devices quite often support CIFS shares, but not S3 nor Evernote directly. This can be combined with Synology's [Cloud Sync](https://www.synology.com/en-global/knowledgebase/DSM/help/CloudSync/cloudsync) to sync scanned files to S3 and use Lambda to trigger automatic workflows which Synology can't do natively. That is the main reason why notebook name and tag are delivered via a prefix and not via tags.
