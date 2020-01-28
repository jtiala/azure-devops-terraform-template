import os
import logging
import azure.functions as func
from pymongo import MongoClient

client = MongoClient(os.getenv("DB_CONNECTION_STRING"))
db = client[os.getenv("DB_NAME")]
visits_count = db.visits.find().count()

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    return func.HttpResponse(f"Total visits: {visits_count}")
