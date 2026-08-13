#remember vm name (must be "iot")
vboxmanage list vmsvboxmanage list vms

vboxmanage startvm "iot"

#if it fails try running on a background
vboxmanage startvm "iot" --type headless
