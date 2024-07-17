#!/bin/sh
#ESXi SMART Script by @Upinel https://upinel.github.io. All Right Reserved.

# Get the list of all device UIDs
device_list=$(esxcli storage core device list | grep -E '^t10.|^eui.' | awk '{print $1}')

# Timestamp for log
timestamp=$(date '+%Y-%m-%d %H:%M:%S')

# Header for the output
header="Drive                                   | Health Status | Drive Temperature | Power-on Hours | Power Cycle Count | Reallocated Sector Count"
separator="---------------------------------------------------------------------------------------------------------------------------------------------"
echo "$header"
echo "$separator"
# Begin logging output with timestamp
{
  echo "Timestamp: $timestamp"
  echo "$header"
  echo "$separator"
} >> smart.log

# Function to process device name
process_device_name() {
    local device_name=$1
    # Replace multiple underscores with a single period
    device_name=$(echo "$device_name" | sed 's/_\+/\./g')
    # Truncate to a maximum of 40 characters
    device_name=$(echo "$device_name" | cut -c 1-40)
    echo "$device_name"
}

# Iterate through each device UID and fetch its SMART data
for device in $device_list
do
    # Process the device name
    processed_device_name=$(process_device_name "$device")
    
    # Get the SMART data
    output=$(esxcli storage core device smart get -d $device)
    
    # Format the output
    formatted_output=$(echo "$output" | awk -v device="$processed_device_name" '
    BEGIN {
        # Initialize default values
        status["Health Status"] = "N/A"
        status["Power-on Hours"] = "N/A"
        status["Drive Temperature"] = "N/A/N/A"
        status["Power Cycle Count"] = "N/A"
        status["Reallocated Sector Count"] = "N/A/N/A"
    }
    # Capture specific parameters and thresholds
    /Health Status/ {status["Health Status"] = $3 ? $3 : "N/A"}
    /Power-on Hours/ {status["Power-on Hours"] = $3 ? $3 : "N/A"}
    /Drive Temperature/ {
        value = $3 ? $3 : "-"
        threshold = $4 ? $4 : "-"
        status["Drive Temperature"] = value "/" threshold
    }
    /Power Cycle Count/ {status["Power Cycle Count"] = $4 ? $4 : "N/A"}
    /Reallocated Sector Count/ {
        value = $4 ? $4 : "0"
        threshold = $5 ? $5 : "-"
        status["Reallocated Sector Count"] = value "/" threshold
    }
    END {
        # Print the results with formatted and truncated drive name (40 characters max)
        printf "%-41s %-15s %-19s %-16s %-19s %-36s\n",
        device,
        status["Health Status"],
        status["Drive Temperature"],
        status["Power-on Hours"],
        status["Power Cycle Count"],
        status["Reallocated Sector Count"]
    }')

    # Append formatted output to the log file
    echo "$formatted_output" >> smart.log
    echo "$formatted_output"
done

# Print an empty line for readability in the log
echo "" >> smart.log
