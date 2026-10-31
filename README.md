# About

A Fusion-MPT SAS Driver which is patched to run on RHEL 9.8 (also only currently tested system). Made for LSI SAS1068E controllers.

The specific kernel version this has been tested on is kernel 5.14.0-687.61.1.el9_8.x86_64 (RHEL 9.8), others might need some tweaks.

# Install Guide 
## Before Install
First, check that the controller is the right one. Run:

```bash
lspci | grep -i SAS1068
```

You should see LSI SAS1068E, if you didn't, then this driver won't work.
Next, check that secure boot is off, otherwise it may not work. Run the following to check:

```bash
mokutil --sb-state
```
If it says its off, hooray, if it's on, disable it.
# Install
## Install Build Tools
The following command installs many of the tools you will need to install the driver:

```bash
sudo dnf install -y gcc make git elfutils-libelf-devel kernel-devel-$(uname -r)
```
Breakdown 
- 'gcc' and 'make' are used to compile the code,
- git is git. Probably have this one already, but better safe than sorry.
- 'elfutils-libelf-devel' is something needed by the linux kernel build system.
- 'kernel-devel-$(uname -r)' installs the headers for your specific kernel. If dnf can't find this one, run:
```bash
sudo dnf update kernel
```
then reboot and try again.

## Download and Build
Clone this repo and cd into it using:
```bash
git clone https://github.com/KermitTheMagnificant/mptsas-e19.git
cd mptsas-e19
```
Once you're in the directory, build it:
```bash
make
```
Hopefully it now works. to test that it did, run the command:
```bash
ls -l *,ko
```
If that command outputs the three files `mptbase.ko`, `mptscsih.ko` and `mptsas.ko`, you did it correctly, good job!

## Installing Modules
Don't have much to say about this to be honest...
```bash
sudo mkdir -p /lib/modules/$(uname -r)/extra
sudo cp mptbase.ko mptscish.ko mptsas.ko /lib/modules/$(uname -r)/extra/
sudo depmod -a
```
Breakdown
- First command makes the 'extra' folder, where the system expects third party modules
- Copies the aforementioned files to the extras folder
- Last command updates the module database to include the brand new ones.

Check the files transferred correctly:
```bash
ls -l /lib/modules/$(uname -r)/extra/
```
## Load The Driver
Now its time to get it actually working!
```bash
sudo modprobe scsi_transport_sas
sudo modprobe -v mptsas
```
It may give you a warning that an out of tree module will 'taint' the kernel... this is expected, don't worry.
## Check That it Worked
```bash
lspci -k | grep -A 3 -i SAS1068
```
You should get something like 'Kernel driver in use: mptsas'
To see the drives, run:
```bash
lsblk
```
You should see the drives handled by the controller that weren't showing up before!
If it isn't, that might just mean the drives aren't part of a RAID array, so do that.

## Finishing Touches
Now we need to make sure it runs on startup.
```bash
echo mptsas | sudo tee /etc/modules-load.d/mptsas.conf
```
Then reboot and run:
```bash
lspci -k | grep -A 3 -i SAS1068
```
To confirm it started up.

## After a Kernel Update
Since this driver only works for this kernel, you'll need to remake it after a kernel update. running the following commands will do that (more indepth documentation in the future, probably)
```bash
    sudo dnf install -y kernel-devel-$(uname -r)
    cd mptsas-el9
    make clean
    make
    sudo mkdir -p /lib/modules/$(uname -r)/extra
    sudo cp mptbase.ko mptscsih.ko mptsas.ko /lib/modules/$(uname -r)/extra/
    sudo depmod -a
    sudo modprobe mptsas
```

## Uninstall
To uninstall, run:
```bash
    sudo modprobe -r mptsas mptscsih mptbase
    sudo rm /lib/modules/$(uname -r)/extra/mpt*.ko
    sudo rm -f /etc/modules-load.d/mptsas.conf
    sudo depmod -a
```

## License

GPL-2.0, the same as the Linux kernel. See the headers in the source files.
