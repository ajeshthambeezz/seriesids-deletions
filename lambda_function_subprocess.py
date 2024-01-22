import subprocess
import boto3
from io import BytesIO

def lambda_handler(event, context):
    # SFTP server details and AWS credentials
    sftp_hostname = 'on.tmstv.com'
    sftp_port = 22
    sftp_username = 'dshmxco'
    sftp_password = '123456'

    aws_access_key_id = 'AKIA4JFGYZ44VHG2ZP7G'
    aws_secret_access_key = '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'
    s3_bucket_name = 'gracenoteepgfiles'
    s3_object_key = 'on_dshm_tv_celebrities_v22_20240121.xml.gz'
    remote_file_path = '/On2/dshm/on_dshm_tv_celebrities_v22_20240121.xml.gz'

    # Download the file using a command-line SFTP client
    sftp_command = f"sftp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P {sftp_port} {sftp_username}@{sftp_hostname}:{remote_file_path}"
    download_command = f"get {remote_file_path} -"
    sftp_process = subprocess.Popen(sftp_command, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = sftp_process.communicate(input=download_command.encode())

    # Upload the file to S3
    local_file = BytesIO(stdout)
    s3 = boto3.client('s3', aws_access_key_id=aws_access_key_id, aws_secret_access_key=aws_secret_access_key)
    s3.upload_fileobj(local_file, s3_bucket_name, s3_object_key)

    return {
        'statusCode': 200,
        'body': 'File successfully transferred from SFTP to S3.'
    }
 