# from __future__ import print_function
import os.path
import sys
import pickle
import googleapiclient.discovery
import google_auth_oauthlib.flow
import google.auth.transport.requests
import base64
import email

# If modifying these scopes, delete the file token.pickle.
SCOPES = ['https://www.googleapis.com/auth/gmail.readonly']

creds = None
if os.path.exists('token.pickle'):
    with open('token.pickle', 'rb') as token:
        creds = pickle.load(token)
if not creds or not creds.valid:
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(google.auth.transport.requests.Request())
    else:
        flow = google_auth_oauthlib.flow.InstalledAppFlow.from_client_secrets_file(
            'credentials.json', SCOPES)
        creds = flow.run_local_server(port=0)
    with open('token.pickle', 'wb') as token:
        pickle.dump(creds, token)

service = googleapiclient.discovery.build('gmail', 'v1', credentials=creds)

def get_all_inbox_messages(service, user_id):
    try:
        return service.users().messages().list(userId=user_id, labelIds="INBOX").execute()
    except Exception as error:
        print('An error occurred: %s' % error)

def get_message(service, user_id, msg_id):
    try:
        return service.users().messages().get(userId=user_id, id=msg_id, format='metadata').execute()
    except Exception as error:
        print('An error occurred: %s' % error)

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

allmessages = get_all_inbox_messages(service, "me")["messages"]
print(get_mime_message(service, "me", allmessages[0]["id"]))

## OLD CODE
# print(get_mime_message(service, "me", "175b168cacb20647"))
# print(get_message(service, "me", "175b168cacb20647"))
# print(get_all_inbox_messages(service, "me"))
# allmids = list(map(lambda x: str(x["id"]), allmessages))
# allmessagecontents = [get_mime_message(service, "me", mid) for mid in allmids]
# print(allmessagecontents)
