# Create AWS Elasticsearch Signed Request

### Description
Create and send a signed authenticated request to your AWS Elasticsearch domain. Accepts a JSON payload as well as configurable ES endpoints and methods. As an example, could be used to retrieve index templates, upsert ingest pipelines, etc.

### Usage
1. Duplicate the `.env-sample` file to `.env` and add your values
2. Run `./request.sh`

### Background
This implementation of Amazon AWS Elasticsearch is based off of a blog post by [ŁUKASZ ADAMCZAK](http://czak.pl/2015/09/15/s3-rest-api-with-curl.html) where the specifics of the signature algorithm are broken down quite nicely.

It seemed like all the online resources I could find for this simply suggested using a platform sdk to handle the signing. But this seemed like a fun thing to do in bash, so here we are.
