#!/bin/bash

# Log file
log_file="script_log.txt"

# Function to display usage information
display_usage() {
    echo "Usage: $0 <input_folder> <num_records_per_file> <date_time_col> <subscriber_col>"
}

# Function to log messages with milliseconds
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S.%3N") - $1" >> "$log_file"
}

# Function to print a dotted line in the log file
print_dotted_line() {
    echo "------------------------------------------------------------" >> "$log_file"
}

# Record start time
start_time=$(date +%s.%3N)
log_message "Start time: $(date +"%Y-%m-%d %H:%M:%S.%3N")"

# Check if the input folder, number of records per file, date-time column, and subscriber column are provided
if [ $# -lt 4 ]; then
    log_message "Error: Insufficient arguments."
    display_usage
    exit 1
fi

# Input folder
input_folder="$1"

# Number of records per output file
num_records_per_file="$2"

# Date-time column number
date_time_col="$3"

# Subscriber column number
subscriber_col="$4"

# Check if the input folder exists
if [ ! -d "$input_folder" ]; then
    log_message "Error: Input folder '$input_folder' does not exist."
    display_usage
    exit 1
fi

# Temporary and output folders based on the input folder name
output_folder="${input_folder}_arc_input_sorted"
merged_file="${input_folder}_merged_input.csv"
temp_file="${input_folder}_tmp_sorted"

# echo "$output_folder"

# If output folder exists, delete it
if [ -d "$output_folder" ]; then
    rm -rf "$output_folder"
fi

# Create the output folder
mkdir "$output_folder"
chmod 777 "$output_folder"

# Sort each CSV file individually and merge them into a single file
for file in "$input_folder"/*.csv; do
    sorted_file="${file%.csv}_sorted.csv"

    # Record the start time for this file
    start_time=$(date +%s.%3N)

    if ! sort -t ',' -k"$subscriber_col","$subscriber_col" -k"$date_time_col","$date_time_col"n "$file" > "$sorted_file"; then
        log_message "Error: Failed to sort file '$file'."
        exit 1
    fi

    # Record the end time for this file
    end_time=$(date +%s.%3N)

    # Calculate the elapsed time
    elapsed_time=$(awk -v start="$start_time" -v end="$end_time" 'BEGIN { printf "%.3f", end - start }')

    # Log the processing time for this file
    log_message "Sorted file '$file' in $elapsed_time seconds"

    cat "$sorted_file" >> "$merged_file"
    rm "$sorted_file"
done

# Convert epoch milliseconds to human-readable date format
if ! awk -v col="$date_time_col" -F',' -v OFS=',' '
{
    # Convert epoch milliseconds to seconds
    epoch = $col / 1000;

    # Format the date and time
    cmd = "date -d @" epoch " +\"%Y-%m-%d %H:%M:%S\"";
    cmd | getline formatted_date;
    close(cmd);

    # Replace the epoch milliseconds with formatted date
    $col = formatted_date;

    # Print the line with the converted date
    print $0;
}' "$merged_file" > "$temp_file"; then
    log_message "Error: Failed to convert epoch milliseconds."
    exit 1
fi

mv "$temp_file" "$merged_file"

# Initialize the file counter and the mapping of subscribers to files
declare -A subscriber_map
file_counter=1

# Process each line, assigning each subscriber to a specific output file
awk -v col="$subscriber_col" -F',' -v outdir="$output_folder" -v counter="$file_counter" -v num_records="$num_records_per_file" '

{
    subscriber = $col;
    if (!(subscriber in subscriber_map)) {
        # Assign a new file name to this subscriber
        subscriber_map[subscriber] = sprintf("%s/output_%d.csv", outdir, counter++);
    }

    # Print the line to the appropriate file
    print $0 >> subscriber_map[subscriber];
}
' "$merged_file"

# Rename output files with a timestamp
for file in "$output_folder"/output_*.csv; do
    timestamp=$(date +"%Y%m%d%H%M%S.%3N")
    mv "$file" "$output_folder/${timestamp}.csv"
    sleep 0.001  # Ensure different timestamps for each file
done

# Remove the temporary files
rm "$merged_file"

# Record end time
end_time=$(date +%s.%3N)

# Calculate elapsed time using awk instead of bc
elapsed_time=$(awk -v start="$start_time" -v end="$end_time" 'BEGIN { printf "%.3f", end - start }')
log_message "Conversion and sorting completed. Elapsed time: $elapsed_time seconds."

chmod 777 "$output_folder"

echo "${output_folder}"

# Print dotted line at the end of the script log
print_dotted_line

# Attempt to delete files in the input folder
log_message "Attempting to delete files in $input_folder"
find "$input_folder" -type f -exec chmod +w {} \;  # Ensure files are writable before deletion
# find "$input_folder" -type f -exec rm {} \;       # Delete each file

# Check if deletion was successful
deleted_files=$(find "$input_folder" -type f)
if [ -z "$deleted_files" ]; then
    log_message "All files in $input_folder deleted successfully."
else
    log_message "Failed to delete some files in $input_folder."
fi

# Print dotted line at the end of the script log
print_dotted_line
