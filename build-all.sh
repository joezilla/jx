
make clean

# build disk image with basic
echo "Building basic config, real hardware"
make CONFIG=config.mk.basic  disk

# build monitor 
echo "Building monitor config, real hardware"
make CONFIG=config.mk.mon disk

echo "Disk images are now in the dist/ directory"

