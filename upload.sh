#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 -f <file_path1> [file_path2 file_path3 ...]"
    exit 1
}

# Function to check AWS credentials and configuration
check_aws_config() {
    if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$AWS_DEFAULT_REGION" ] || [ -z "$S3_BUCKET" ]; then
        echo "AWS credentials and configuration not set. Please configure the script with your AWS details."
        exit 1
    fi
}

# Function to upload a file to S3
upload_file() {
    local file_path=$1
    local file_name=$(basename "$file_path")

    if aws s3 ls "s3://$S3_BUCKET/$file_name" 2>/dev/null; then
        read -p "File '$file_name' already exists in S3. Do you want to (O)verwrite, (S)kip, or (R)ename the file? [O/S/R]: " choice
        case $choice in
            [Oo])
                pv "$file_path" | aws s3 cp - "s3://$S3_BUCKET/$file_name"
                ;;
            [Ss])
                echo "Skipped uploading '$file_name' to S3."
                return
                ;;
            [Rr])
                local new_name="${file_name}_$(date +%Y%m%d%H%M%S)"
                pv "$file_path" | aws s3 cp - "s3://$S3_BUCKET/$new_name"
                echo "File renamed to '$new_name' and uploaded to S3 bucket."
                ;;
            *)
                echo "Invalid choice. Exiting without uploading."
                exit 1
                ;;
        esac
    else
        pv "$file_path" | aws s3 cp - "s3://$S3_BUCKET/$file_name"
    fi

    if [ $? -eq 0 ]; then
        echo "File '$file_name' successfully uploaded to S3 bucket."
        read -p "Do you want to generate and display a shareable link for '$file_name'? (Y/N): " link_choice
        case $link_choice in
            [Yy])
                local s3_link=$(aws s3 presign "s3://$S3_BUCKET/$file_name")
                echo "Shareable link for '$file_name': $s3_link"
                ;;
            [Nn])
                ;;
            *)
                echo "Invalid!. Continuing without generating a link."
                ;;
        esac
    else
        echo "Error uploading file '$file_name' to S3. Check your configuration and try again."
    fi
}

# Main script execution
main() {
    check_aws_config

    if [ $# -eq 0 ]; then
        usage
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -f)
                shift
                files=("$@")
                break
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done

    if [ ${#files[@]} -eq 0 ]; then
        usage
    fi

    for file_path in "${files[@]}"; do
        upload_file "$file_path"
    done
}

# Run the main function
main "$@"
