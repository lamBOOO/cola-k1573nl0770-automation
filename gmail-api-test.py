from __future__ import print_function
import pickle
import os.path
from googleapiclient.discovery import build
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
import base64
import email

# If modifying these scopes, delete the file token.pickle.
SCOPES = ['https://www.googleapis.com/auth/gmail.readonly']

def main():
    """Shows basic usage of the Gmail API.
    Lists the user's Gmail labels.
    """
    creds = None
    # The file token.pickle stores the user's access and refresh tokens, and is
    # created automatically when the authorization flow completes for the first
    # time.
    if os.path.exists('token.pickle'):
        with open('token.pickle', 'rb') as token:
            creds = pickle.load(token)
    # If there are no (valid) credentials available, let the user log in.
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                'credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)
        # Save the credentials for the next run
        with open('token.pickle', 'wb') as token:
            pickle.dump(creds, token)

    service = build('gmail', 'v1', credentials=creds)

    # Call the Gmail API
    results = service.users().labels().list(userId='me').execute()
    labels = results.get('labels', [])

    if not labels:
        print('No labels found.')
    else:
        print('Labels:')
        for label in labels:
            print(label['name'])

    def get_messages(service, user_id):
        try:
          print("HI")
          return service.users().messages().list(userId=user_id, labelIds="INBOX").execute()
        except Exception as error:
          print('An error occurred: %s' % error)

    print(get_messages(service, "me"))

    def get_message(service, user_id, msg_id):
        try:
          return service.users().messages().get(userId=user_id, id=msg_id, format='metadata').execute()
        except Exception as error:
          print('An error occurred: %s' % error)

    # print(get_message(service, "me", "175b168cacb20647"))

    def get_mime_message(service, user_id, msg_id):
        try:
          message = service.users().messages().get(userId=user_id, id=msg_id,
                                                  format='raw').execute()
          print('Message snippet: %s' % message['snippet'])
          msg_str = base64.urlsafe_b64decode(message['raw'].encode("utf-8")).decode("utf-8")
          mime_msg = email.message_from_string(msg_str)

          return mime_msg
        except Exception as error:
          print('An error occurred: %s' % error)

    print(get_mime_message(service, "me", "175b168cacb20647"))

if __name__ == '__main__':
    main()
