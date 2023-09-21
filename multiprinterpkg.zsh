#!/bin/zsh

# Clean up stray .pkg files in /tmp
echo "Cleaning up stray .pkg files in /tmp..."
rm -f /tmp/*.pkg

# Initialize the sign_identity variable as empty
sign_identity=""

# Loop through arguments to find --sign
for arg in "$@"; do
  shift
  case "$arg" in
    "--sign") set -- "$@" "-s" ;;
    *)        set -- "$@" "$arg"
  esac
done

# Parse the arguments
OPTIND=1
while getopts 's:' opt; do
  case "$opt" in
    s) sign_identity=$OPTARG ;;
  esac
done

# Logging function
log() {
    echo "$1"
    echo "$1" >> "${work_dir}/printer_package.log"
}

# Cleanup function
cleanup() {
    log "Caught an error! Cleaning up..."
    rm -rf "${work_dir}/${package_name}"
}

# Set a trap for cleanup upon errors
trap cleanup ERR

# Unlock keychain if --sign is specified
#THIS IS VERY INSECURE, THIS WILL OPEN THE KEYCHAIN FOR 1 MINUTE TO PFREVENT YOU TO ALWAYS ENTER YOUR PASSWORD
#AT THE END OF THE SCRIPT THE KEYCHAIN WILL BE LOCKED. IF SOMEONE STOPS THE SCRIPT IT, THE KEYCHAIN WILL BE OPEN FOR 60 SECONDS
#PLEASE DO NOT UNCOMMENT THESE LINES, IF NOT NEEDED

#if [ -n "$sign_identity" ]; then
#    echo "Please enter the keychain password: "
#	read -s keychain_password
#	echo "Unlocking keychain..."
#	security unlock-keychain -p $keychain_password ~/Library/Keychains/login.keychain
#	security set-keychain-settings -t 60 -l ~/Library/Keychains/login.keychain
#fi

# Define the working directory
#work_dir=~/printer_packages
work_dir=$(pwd)

# Create the working directory if it does not exist
mkdir -p $work_dir || { echo "Failed to create working directory."; exit 1; }

# Read the CSV line by line
while IFS=, read -r pkg_version old_printer_name new_printer_name new_printer_location new_printer_driver_location new_printer_ip printer_options package_name driver_location; do
  # ... (other parts of your script)

	# Skip if any key variables are empty
	if [[ -z $new_printer_name || -z $package_name ]]; then
    	echo "Skipping empty or malformed line."
    	continue
	fi


    # Skip the header line
    if [[ $old_printer_name == "OldPrinterName" ]]; then
        continue
    fi

    #echo "Creating package for $new_printer_name..."
    log "Creating package for $new_printer_name..."  # Changed from echo to log

    # Create necessary directories and files
    mkdir -p "${work_dir}/${package_name}/Payload/tmp" || { echo "Failed to create Payload/tmp directory."; continue; }
    mkdir -p "${work_dir}/${package_name}/scripts" || { echo "Failed to create scripts directory."; continue; }
    echo "Printer Installation PKG." > "${work_dir}/${package_name}/Payload/tmp/printer_installation.txt"


 	#Download the driver
  	#driver_filename=$(basename "$driver_location")
  	#curl -o "${work_dir}/${package_name}/Payload/tmp/${driver_filename}" "$driver_location" || { echo "Failed to download driver."; continue; }

	# Then download the driver
	driver_filename=$(basename "$driver_location")
	file_extension="${driver_filename##*.}"
	curl -o "/tmp/${driver_filename}" "$driver_location" || { echo "Failed to download driver."; exit 1; }

	if [ "$file_extension" = "zip" ]; then
    unzip -o "/tmp/${driver_filename}" -d "${work_dir}/${package_name}/Payload/tmp" || { echo "Failed to unzip driver."; exit 1; }
    
    # Remove __MACOSX folder if it exists
    if [ -d "${work_dir}/${package_name}/Payload/tmp/__MACOSX" ]; then
        rm -rf "${work_dir}/${package_name}/Payload/tmp/__MACOSX"
    fi

    # Determine the package filename
    pkg_filename=$(ls "${work_dir}/${package_name}/Payload/tmp" | grep '.pkg' | head -n 1)
    if [ -z "$pkg_filename" ]; then
        echo "No .pkg file found."
        exit 1
    fi

else
    pkg_filename=${driver_filename}
fi

	# Create postinstall script
	echo "#!/bin/sh" > "${work_dir}/${package_name}/scripts/postinstall"
	echo "## postinstall" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "pathToScript=\$0" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "pathToPackage=\$1" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "targetLocation=\$2" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "targetVolume=\$3" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "old_printer_name=\"$old_printer_name\"" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "new_printer_name=\"$new_printer_name\"" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "new_printer_location=\"$new_printer_location\"" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "new_printer_driver_location=\"$new_printer_driver_location\"" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "new_printer_ip=\"$new_printer_ip\"" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "# Install the driver" >> "${work_dir}/${package_name}/scripts/postinstall"
  	echo "/usr/sbin/installer -pkg /tmp/$pkg_filename -target /" >> "${work_dir}/${package_name}/scripts/postinstall"  	
	echo "# Add your shell commands here" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "# Use lpstat to list all printers and grep to check for your specific printer" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "if lpstat -p | grep -q \$old_printer_name; then" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    # Stop the CUPS service" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    #launchctl bootout system /System/Library/LaunchDaemons/org.cups.cupsd.plist" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    #sleep 2" >> "${work_dir}/${package_name}/scripts/postinstall"

	# Remove the old printer
	echo "    if [ -n \"\$old_printer_name\" ]; then" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "        if lpadmin -x \$old_printer_name; then" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "            echo \"Successfully removed old printer \$old_printer_name.\"" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "        else" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "            echo \"Failed to remove old printer \$old_printer_name.\"" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "            exit 1" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "        fi" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    else" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "        echo \"No old printer specified. Skipping removal.\"" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    fi" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    fi" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    # Start the CUPS service" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    #launchctl bootstrap system /System/Library/LaunchDaemons/org.cups.cupsd.plist" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    #sleep 2" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    # Add new printer" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    if lpadmin -p \$new_printer_name -L \$new_printer_location -E -v \$new_printer_ip -P \$new_printer_driver_location -o $printer_options; then" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    #if lpadmin -p \$new_printer_name -L \$new_printer_location -E -v \$new_printer_ip -P \$new_printer_driver_location -o printer-is-shared=false; then" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "        echo \"Successfully added new printer \$new_printer_name.\"" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "        exit 0" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    else" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "        echo \"Failed to add new printer \$new_printer_name.\"" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "        exit 1" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    fi" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "else" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    echo \"Old printer \$old_printer_name is not installed. Doing nothing.\"" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "    exit 0" >> "${work_dir}/${package_name}/scripts/postinstall"
	echo "fi" >> "${work_dir}/${package_name}/scripts/postinstall"

    # Make postinstall script executable
    chmod +x "${work_dir}/${package_name}/scripts/postinstall" || { echo "Failed to make postinstall executable."; continue; }


    # Create the package using pkgbuild
	if [ -n "$sign_identity" ]; then
  	pkgbuild --root "${work_dir}/${package_name}/Payload" \
    		--scripts "${work_dir}/${package_name}/scripts" \
           	--identifier "ch.muehlenberg.pkg.${package_name}" \
           	--version "$pkg_version" \
           	--sign "$sign_identity" \
           "${work_dir}/${package_name}.pkg" || { echo "Failed to build package."; continue; }
	else
  	pkgbuild --root "${work_dir}/${package_name}/Payload" \
           	--scripts "${work_dir}/${package_name}/scripts" \
           	--identifier "ch.muehlenberg.pkg.${package_name}" \
           	--version "$pkg_version" \
           	"${work_dir}/${package_name}.pkg" || { echo "Failed to build package."; continue; }
	fi

    # Clean up
    rm -rf "${work_dir}/${package_name}" || { echo "Failed to remove working directory."; continue; }

done < "printers.csv"

#LOCK KEYCHAIN
#echo "Locking keychain..."
#security lock-keychain ~/Library/Keychains/login.keychain