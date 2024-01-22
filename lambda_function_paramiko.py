# import boto3
import paramiko
import os
def lambda_handler(event, context):
    # SFTP server details and AWS credentials
    sftp_hostname = 'on.tmstv.com'
    sftp_port = 22
    sftp_username = 'dshmxco'
    sftp_password = '846df123'
    
    aws_access_key_id = 'AKIA4JFGYZ44VHG2ZP7G'
    aws_secret_access_key = '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'
    s3_bucket_name = 'gracenoteepgfiles'
    s3_object_key = 'on_dshm_tv_celebrities_v22_20240115.xml.gz'
    remote_file_path = '/On2/dshm/on_dshm_tv_celebrities_v22_20240115.xml.gz'
    local_file_path = '/tmp/on_dshm_tv_celebrities_v22_20240115.xml.gz'
    
    # # SFTP server details and AWS credentials
    # Create an SSH client
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    # Connect to the SFTP server
    ssh.connect(sftp_hostname, sftp_port, sftp_username, sftp_password)
    # Open an SFTP session on the SSH connection
    sftp = ssh.open_sftp()
    # # Download the file from the SFTP server
    sftp.get(remote_file_path, local_file_path)
    # Upload the file to S3
    s3 = boto3.client('s3', aws_access_key_id=aws_access_key_id, aws_secret_access_key=aws_secret_access_key)
    s3.upload_file(local_file_path, s3_bucket_name, s3_object_key)
    # Remove the local file
    os.remove(local_file_path)
    # Close the SFTP session and the SSH connection
    sftp.close()
    ssh.close()
    
    
    return {
    'statusCode': 200,
    'body': 'File successfully transferred from SFTP to S3.'
    }
