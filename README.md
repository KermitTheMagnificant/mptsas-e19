# About

A Fusion-MPT SAS Driver which is patched to run on RHEL 9.8 (also only currently tested system). Made for LSI SAS1068E controllers.

The specific kernel version this has been tested on is kernel 5.14.0-687.61.1.el9_8.x86_64 (RHEL 9.8), others might need some tweaks.
You can either build it manually using the below build instructions, or use install.sh to install it yourself.

# Automatic Install Guide
cd into the directory of the repo after download and run ./install.sh.
What does it do?
1. Re-runs itself with sudo if you aren’t root.
2. Checks that it’s inside the repo folder and that the source files are there.
3. Looks for the SAS1068 controller with lspci and asks before continuing if it isn’t found.
4. Checks Secure Boot with mokutil and warns if it’s enabled, since the module won’t load then.
5. Installs gcc, make, elfutils-libelf-devel and the kernel-devel package that matches the running kernel.
6. Runs make clean and make, then confirms that all three .ko files were built.
7. Copies the modules to /lib/modules/<kernel>/extra/ and runs depmod -a.
8. Writes /etc/modules-load.d/mptsas.conf so the driver loads at boot.
9. Loads the driver with modprobe, then prints lsmod, lspci -k and lsblk so you can see whether it worked.

# Manual Install Guide 
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
