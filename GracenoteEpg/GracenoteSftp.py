# # import paramiko

# # # Replace these values with your own SFTP server details
# # hostname = 'on.tmstv.com'
# # port = 22
# # username = 'dshmxco'
# # password = '846df123'

# # # Create an SSH client
# # ssh = paramiko.SSHClient()

# # # Automatically add the server's host key (this is insecure and should be avoided in a production environment)
# # ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

# # # Connect to the server
# # ssh.connect(hostname, port, username, password)

# # # Open an SFTP session on the SSH connection
# # sftp = ssh.open_sftp()

# # # Now you can perform SFTP operations
# # # For example, you can download a file from the server:
# # remote_file_path = '/On2/dshm/on_dshm_tv_celebrities_v22_20240115.xml.gz'
# # local_file_path = 'Files/on_dshm_tv_celebrities_v22_20240115.xml.gz'  # Specify the full local file path

# # sftp.get(remote_file_path, local_file_path)

# # # Close the SFTP session and the SSH connection when done
# # sftp.close()
# # ssh.close()




# import boto3
# import paramiko
# import os

# hostname = 'on.tmstv.com'
# port = 22
# username = 'dshmxco'
# password = '846df123'

# # Replace these values with your own AWS and SFTP server details
# aws_access_key_id = 'AKIA4JFGYZ44VHG2ZP7G'
# aws_secret_access_key = 'ytJjAHEeTSkLwNh4FKsXzAOKafmcLQahCMbtM6Mk'
# s3_bucket_name = 'gracenoteepgfiles'
# s3_object_key = "on_dshm_tv_celebrities_v22_20240115.xml.gz"  # Specify the desired S3 object key
# remote_file_path = '/On2/dshm/on_dshm_tv_celebrities_v22_20240115.xml.gz'

# # Create an SSH client
# ssh = paramiko.SSHClient()

# # Automatically add the server's host key (this is insecure and should be avoided in a production environment)
# ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

# # Connect to the server
# ssh.connect(hostname, port, username, password,look_for_keys=False, allow_agent=False)

# # Open an SFTP session on the SSH connection
# sftp = ssh.open_sftp()

# # Download the file from the SFTP server
# local_file_path = 'Files/on_dshm_tv_celebrities_v22_20240115.xml.gz'
# sftp.get(remote_file_path, local_file_path)


# # Close the SFTP session and the SSH connection
# sftp.close()
# ssh.close()

# # Upload the file to S3
# s3 = boto3.client('s3', aws_access_key_id=aws_access_key_id, aws_secret_access_key=aws_secret_access_key)
# s3.upload_file(local_file_path, s3_bucket_name, s3_object_key)

# # Remove the local file if needed
# os.remove(local_file_path)









import boto3
import paramiko
import os

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

def lambda_handler(event, context):
    # # SFTP server details and AWS credentials
    # sftp_hostname = 'on.tmstv.com'
    # sftp_port = 22
    # sftp_username = 'dshmxco'
    # sftp_password = '846df123'

    # aws_access_key_id = 'AKIA4JFGYZ44VHG2ZP7G'
    # aws_secret_access_key = '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'
    # s3_bucket_name = 'gracenoteepgfiles'
    # s3_object_key = 'on_dshm_tv_celebrities_v22_20240115.xml.gz'

    # Create an SSH client
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    # Connect to the SFTP server
    ssh.connect(sftp_hostname, sftp_port, sftp_username, sftp_password)

    # Open an SFTP session on the SSH connection
    sftp = ssh.open_sftp()

    # # Download the file from the SFTP server
    # remote_file_path = '/On2/dshm/on_dshm_tv_celebrities_v22_20240115.xml.gz'
    # local_file_path = '/tmp/on_dshm_tv_celebrities_v22_20240115.xml.gz'
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
