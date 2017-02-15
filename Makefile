FUNCTION_NAME=s3-to-evernote
# IAM policy name granting access to relevant S3 buckets
FUNCTION_BUCKET_POLICY=s3-to-evernote
# comma separated list of evernote tags to apply to every created note
STATIC_TAGS=archivebox001
# s3-to-evernote will delete objects after import if this is true
DELETE_IMPORTED_FILES=0
# evernote dev token obtained via https://www.evernote.com/api/DeveloperToken.action
# Note: encrypt this for maximum security: http://docs.aws.amazon.com/lambda/latest/dg/env_variables.html
EVERNOTE_DEV_TOKEN=REPLACE_WITH_EVERNOTE_TOKEN

ACCOUNT_ID=$(shell aws sts get-caller-identity --output text --query 'Account')
LAMBDA_ENVIRONMENT="{token=$(EVERNOTE_DEV_TOKEN),static_tags=$(STATIC_TAGS),delete_imported_files=$(DELETE_IMPORTED_FILES)}"

VPATH=build

.PHONY: clean test deploy all


all: $(FUNCTION_NAME).zip

clean:
	rm -rf build/*


test: build/$(FUNCTION_NAME).zip
	aws lambda invoke --function-name $(FUNCTION_NAME) output.txt; cat output.txt; echo; rm output.txt


deploy: build/$(FUNCTION_NAME).zip build/role
	aws lambda list-functions --query "Functions[?FunctionName=='$(FUNCTION_NAME)'].FunctionArn | [0]" --output text > build/function
	if grep -Fxq None build/function ; then \
		aws lambda create-function --function-name $(FUNCTION_NAME) --runtime python2.7 --handler handler.lambda_handler --role `cat build/role` --zip-file fileb://$< --query FunctionArn --timeout 10 --environment Variables=$(LAMBDA_ENVIRONMENT) --description "Imports files on S3 to Evernote" --output text > build/function ; \
	else \
		aws lambda update-function-code --function-name $(FUNCTION_NAME) --zip-file fileb://$< ; \
	fi


build/role:
	aws iam list-roles --query "Roles[?RoleName=='$(FUNCTION_NAME)'].Arn | [0]" --output text > build/role
	if grep -Fxq None build/role ; then \
		aws iam create-role --role-name $(FUNCTION_NAME) --assume-role-policy-document '{"Statement":[{"Sid":"","Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' --query 'Role.Arn' --output text > build/role ; \
		aws iam attach-role-policy --role-name $(FUNCTION_NAME) --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole ; \
		aws iam attach-role-policy --role-name $(FUNCTION_NAME) --policy-arn arn:aws:iam::$(ACCOUNT_ID):policy/$(FUNCTION_BUCKET_POLICY) ; \
	fi


build/$(FUNCTION_NAME).zip: build/packages.zip handler.py
	cp $< $@
	zip -9 $@ `echo $^ |cut -d " " -f2-`


build/packages.zip: requirements.txt
	mkdir -p build/packages
	pip install -I -b build -t build/packages -r requirements.txt
	(cd build/packages; zip -9 -r ../packages.zip .)
