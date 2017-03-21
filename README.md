# Introduction

meta-flatpak is a Yocto layer with the primary aim to add support
for compiling, installing and running flatpak applications on devices
with a flatpak-enabled Yocto image.

Flatpak (http://flatpak.org) is a framework for building, distributing
and installing applications. It conceptually splits the software stack
into commonly used bits (runtimes, runtime SDKs) and application-specific
bits (the application itself). Flatpak decouples the lifecycle of the
application from the lifecycle of the underlying OS/distro. The distro
and the applications can be updated independently from each other. Flatpak
additionally provides application sandboxing out of the box and an
infrastructure for application deployment.

Flatpak relies on OSTree/libOSTree (http://ostree.readthedocs.io.)
as the distribution mechanism for applications and runtimes. OSTree is
a library and suite of command line tools that provide a version
control and distribution mechanism for bootable OS filesystem trees,
or other binaries. It is very 'git-like' and indeed it has been
largely inspired by git. OSTree also contains functionality for
managing the boot loader configuration as OSTree-managed filesystem
trees are deployed.

For more information about flatpak and OSTree please refer to their
corresponding documentations at the sites dedicated to these projects.


# Basic Flatpak Functionality

Flatpak provides a managed runtime by splitting up the software stack
roughly into three categories: runtimes, runtime SDKs, and the applications
themselves.

Runtimes are the common shared userspace functionality sitting above the
kernel and below the applications in the stack. In a Linux desktop stack
a runtime could include, for instance, the posix-compatible libraries,
X11 libraries, wayland, and the gnome desktop. Another one could provide
the KDE desktop instead of gnome, while a third one could opt for Xfce4,
instead.

The runtime SDKs include the runtime itself, the compiler toolchain and
the necessary other development tools for compiling and developing for
the runtime and the necessary headers, libraries, etc.

Finally, the applications contain the application-specific bits and
at least any libraries they use which are not provided by the runtime,
although they choose to do so they can contain a copy of all the
libraries they depend on.

With this setup, to install an application you install the runtime the
application was compiled against and the application itself. If several
applications use the same version of the same runtime, which is usually
the case, they share a single copy of that runtime version. Also, when
a runtime is updated, two or more versions can be co-hosted parallel
as long as necessary, until all the applications have been updated to
use the latest one.

To develop/compile an application, you install the runtime SDK on your
development machine and use flatpak-build to compile against your target
runtime and SDK.

Runtimes, runtime SDKs and applications are kept and published in flatpak
repositories, which are OSTree repositories with a flatpak-specific layout.
Repositories in archive-z2 format can be published over HTTP using any
HTTP server. Applications, runtimes, and runtime SDKs are pulled into
devices and development hosts from these published repositories. The
repositories support tags and branches in a git-like manner, allowing one
to easily manage paraller versions and configurations of the same software.
Additionally, repositories support GPG-signing for verifying the
authenticity and intactness of the published components.


# OSTree Functionality

flatpak and consequently meta-flatpak require OSTree, since flatpak
repositories are OSTree repositories with a particular flatpak-specific
filesystem tree layout and branch naming conventions. To be self-contained
meta-flatpak can provide recipes for OSTree and its dependencies. However,
since there are parallel independent efforts/layers to bring OSTree support
to Yocto (meta-updater and meta-ostree, for instance), flatpak can and will
prefer to use OSTree from one of these layers, if it is present and enabled
(provided the layer has its priority set to 6 or higher).

In the absence of an external OSTree layer, the OSTree functionality provided
by meta-flatpak is limited to merely making the OSTree binaries and libraries
available. In particular, meta-flatpak does not provide any integration of
OSTree to image update process and bootloader.


# Additional Functionality

In addition to the basic flatpak functionality meta-flatpak contains a
small daemon, flatpak-session, that if enabled will monitor certain
remotes, install and update applications published there and automatically
start these applications at system startup time.

The pre-conditions for a remote to be treated this way is to

  * have a system user associated with the remote, and
  * the remote to be marked as enumerable

A user is considered to be associated with remote <r> if the users
GECOS is set to "flatpak user for <r>". All applications from a remote
are run within an automatic seatless login session of the associated
user. Currently there is no way to guarantee startup order of applications
if there are more than one installed from a single remote. Applications
are started in the order of discovery.


# Building And Testing meta-flatpak

At the moment the easiest way to test meta-flatpak is to use the pre-
configured repository found at http://github.com/klihub/intel-iot-refkit.
This repository is a clone/fork of http://github.com/intel/intel-iot-refkit
with a few necessary patches and the flatpak layer added on top using git
submodules.


## Getting The Necessary Bits In Place

Clone the repository and let it pull in its submodules:

```
git clone https://github.com/klihub/intel-iot-refkit.git -b intel-iot-refkit/flatpak
git submodule init
git submodule update --recursive
```

## Configuring Your Builds

Next you need to tweak your default configuration a little bit to
enable flatpak and make the built images more friendly for development
or just general poking around. If you're uninterested in the details,
just cut and paste the following section to the end of your
conf/local.conf. Otherwise skip this and read on. We'll be doing the
same thing but one at a time and with a bit of explanation.

```
# Append these to your default build/conf/local.conf.

# Chose the default configuration for developement.
require conf/distro/include/refkit-development.inc

# We'll be using qemu on our host, not real dedicated hardware.
# We'll also want SDL-base VGA emulation for qemu.
MACHINE="qemux86-64"
PACKAGECONFIG_append_pn-qemu-native = " sdl"
PACKAGECONFIG_append_pn-nativesdk-qemu = " sdl"

# We'll want to be able to ssh/scp to/from our box/qemu.
REFKIT_IMAGE_EXTRA_FEATURES = "debug-tweaks"
REFKIT_IMAGE_EXTRA_INSTALL += "openssh-sshd openssh-ssh openssh-scp"
# We'll be playing with applications that need termcap and curses.
REFKIT_IMAGE_EXTRA_INSTALL += "ncurses"

# Pull in the configuration bits for enabling flatpak applications.
require conf/distro/include/flatpak-applications.inc

# By default meta-flatpak will only generate flatpak runtime repositories
# for SDK images. We'll want to also test how we can use flatpak to drop
# into a shell running inside a container with our runtime image. So we
# ask meta flatpak to generate repositories for any flatpak-enabled image.
FLATPAK_IMAGE_PATTERN = "glob:*-flatpak*"
```

Note that in the examples we'll be using qemu on our development host
to run the images we build instead of using real dedicated hardware.
You can change the qemu-related bits in the configuration above if you
prefer to test with real hardware instead.


Alternatively you can execute the following set of commands to get to
an equivalent configuration.

* enable the default development configuration:

```
sed -e 's:^#\(require .*/refkit-dev.*\):\1:' -i conf/local.conf
```

* select 64-bit x86 qemu as the target machine:

```
echo 'MACHINE = "qemux86-64"' >> conf/local.conf
```

* we prefer SDL-based VGA emulation for qemu instead of VNC:

```
echo 'PACKAGECONFIG_append_pn-qemu-native = " sdl"' >> conf/local.conf
echo 'PACKAGECONFIG_append_pn-nativesdk-qemu = " sdl"' >> conf/local.conf
```

* prefer a less secure but more development-friendly setup:

```
echo 'REFKIT_IMAGE_EXTRA_FEATURES = "debug-tweaks"' >> conf/local.conf
```

* install sshd, ssh, and scp for easy copying stuff back and forth:

```
echo 'REFKIT_IMAGE_EXTRA_INSTALL += "openssh-sshd openssh-ssh openssh-scp"' >> conf/local.conf
```

* we'll be compiling applications that need ncurses and termcap:

```
echo 'REFKIT_IMAGE_EXTRA_INSTALL += "ncurses"' >> conf/local.conf
```

* pull in the configuration bits enabling flatpak applications:

```
echo 'require conf/distro/include/flatpak-applications.inc' >> conf/local.conf
```

By default meta-flatpak generates runtime repositories out of flatpak-
enabled SDK-capable images. We'll want to play around with flatpak to
see how we can use it to drop into a shell running in a 'container'
with other runtime images. Hence we change the default configuration to
match all images.

* and finally enable flatpak repository generation for all images:

```
echo 'FLATPAK_IMAGE_PATTERN = "glob:*"' >> conf/local.conf
```


## Building

Remember that if you're running in a different shell (for instance in
a different terminal) than the set of preparating commands from the
previous section, you should initialize your environment for bitbaking.
This is done with the following command:

```
. ./refkit-init-build-env
```

or

```
source ./refkit-init-build-env
```


Okay, now with everything hopefully set up properly, we should be ready
to build a ourselves a few test images and repositories. We'll start with
the flatpak-enabled version of a minimal runtime image.


```
# Build a flatpak enabled minimal image.
bitbake refkit-image-minimal-flatpak-runtime
```

While bitbake is pretty smart about avoiding unnecessary work and
especially compilation, there is no way around the fact that during
your initial build there is a fair bit of code to download and
compile. 

If you don't have a fast machine with lots of memory and fast SSDs or
a very fast internet connection, this might be a good time to make and
grab a cup o'joe, sit back and wonder about whatever is your favourite
pastime subject to wonder about.

Once bitbake is finished you should be left with a bunch of image-related
files in *tmp-glibc/deploy/images/qemux86-64*, all of which should be named
after the image you built, hence in our case
*refkit-image-minimal-flatpak-runtime*.

You should also have a few similarly named flatpak-related files directly
under *build*, your current working directory. These should include:

  * a flatpak (OSTree) repository containing your image (.flatpak)
  * an Apache2 configuration file for exporting your repository (.http.conf)
  * a GPG private key for signing your repository (.sec)
  * a GPG public key for clients to check your signatures (.pub)


Once you have verified you got all these in place, you can go ahead and
build the corresponding SDK image.

```
# Build a flatpak SDK image for the flatpak-enabled minimal image.
bitbake refkit-image-minimal-flatpak-sdk
```

You should get a similar bunch of corresponding image- and flatpak-related
files in *tmp-glibc/deploy/images/qemux86-64* and directly in *build* all
starting with *refkit-image-minimal-flatpak-sdk*.


# Testing

## Testing The Basic Flatpak Functionality

We'd like to test first the full chain of generating and publishing a
flatpak for our device (which in this case is our image running in qemu).
To get from source code to a flatpak application installed on our target
device will take a fair number of steps:

* publishing the repository hosting our flatpak-enabled images
* installing the flatpak SDK image to our development host
* taking some test code and flatpak-building it for our runtime image
* exporting the resulting binary as a flatpak application in a repository
* letting our target device know about the application repository
* pulling in the flatpak application from the repository to the device, and
* testing the application on our device

Let's see what each of these steps means in practice in more detail.

### Publishing SDK Image Repository

We need the SDK runtime to be able to compile for our target device.
With flatpak, the runtime, SDK runtime, and applications are all 
distributed in a uniform way using OSTree repositories. We do have our
freshly built repository available, but we still need to let flatpak
on our develpment machine know about it and access it. Two things are
necessary for this:

* we need to export the repository over HTTP
* we need to let flatpak on our machine know about the repository

meta-flatpak has already generated an apache2 configuration fragment for
exporting the repository. If you run apache on your machine, you simply
need to drop this in place and restart apache. For my distro of choice
this can be accomplished with the following commands:

```
mandark build $ sudo cp ./refkit-image-minimal-flatpak-sdk.flatpak.http.conf /etc/httpd/conf.d
mandark build $ sudo systemctl restart httpd
```

Next we need to let flatpak on our machine know about the repository. This
can be done with the following command. If you're unsure about the correct
URI and filesystem paths, take peak inside the generate http.conf file.

```
mandark build $ flatpak remote-add refkit-image-minimal-flatpak-sdk --gpg-import=./refkit-signing.pub http://127.0.0.1/flatpak/refkit-image-minimal/sdk
```

You should be able to see now your newly added remote repository when you
list the available remotes on your machine:

```
mandark build $ flatpak remote-list
gnome                           
refkit-image-minimal-flatpak-sdk
refkit-runtime                  
refkit-runtime-minimal          
com.spotify.Client-1-origin     
com.spotify.Client-2-origin     
com.spotify.Client-3-origin     
com.spotify.Client-4-origin     
com.spotify.Client-origin       
```

You should see *refkit-image-minimal-flatpak-sdk* show up in the list.
Additionally, you should see our SDK if you list the runtimes available
from that remote:

```
mandark build $ flatpak remote-ls --runtime -d refkit-image-minimal-flatpak-sdk
runtime/iot.refkit.BaseSdk/x86_64/20170210162508 a9b9124b15e3
runtime/iot.refkit.BaseSdk/x86_64/current 71eedc5de6e8
```

You should see *iot.refkit.BaseSdk* show up among the listed runtimes.
Let's pull in the SDK runtime to our machine with the following command.

```
mandark build $ flatpak install refkit-image-minimal-flatpak-sdk iot.refkit.BaseSdk runtime/x86_64/current
Warning: Can't find dependencies: No flatpak cache in remote summary
Updating: iot.refkit.BaseSdk/x86_64/current from refkit-image-minimal-flatpak-sdk

110 metadata, 1515 content objects fetched; 12646 KiB transferred in 1 seconds  
Now at 71eedc5de6e8.
```

We chose to install the branch runtime/x86_64/current which meta-flatpak
always sets to point to the last version built. If you want to see all
available versions, you can run

If everything went ok this far, we should be now ready to compile some
test application for our target device using the flatpak runtime SDK.
Since our image probably does not have a proper editor like emacs, let's
clone vim and try to flatpak-build it so that we can do at least some
basic editing on the device.

```
mandark build $ mkdir test
mandark build $ cd test
mandark test $ git clone https://github.com/vim/vim.git
```

Next we create a directory for flatpak-build to put files into and
initialize and initialize flatpak-build to point to it and tell it
the runtime, SDK version and application name and version we'll be
using and building.

```
mandark test $ mkdir build.vim
mandark test $ flatpak build-init build.vim org.vim.vim iot.refkit.BaseSdk iot.refkit.BasePlatform current
```

If everything went successfully, we're now ready to go through the
ordinary configure/compile/install cycle for our application. We just
need to remember to prefix all these commands with flatpak build to
let it do its magic.

```
mandark test $ cd vim
mandark vim $ flatpak build ../build.vim ./configure --prefix=/app
...
mandark vim $ flatpak build ../build.vim make
...
mandard vim $ flatpak build ../build.vim make install
```

The first flatpak build/configure command configures vim for building
as a flatpak application. Flatpak expects all files belonging to the
application relocated under /app so we provide the necessary option
to configure. The second and third commands simply run the normal
compilation and installation commands under flatpak build.

If all went fine, we should next finalize the build, telling flatpak
how our application should be started. Additionally we'll tell flatpak
that our application will need fill read-write access to the home
directory. Our editor would not be very handy if it couldn't save files.
If we wanted to give our editor read-write access to other directories
we can do so by giving more similar command-line arguments. If we wanted
to provide access to the whole filesystem we could use 'host' as the
argument instead of 'home' or a particular path. Read-only access can be
granted by appending :ro to the argument. For more options controlling
the sandboxing features of flatpak for an application see the manual page
of flatpak-build-finish(1).

```
mandard vim $ flatpak build-finish ../build.vim --command=vim --filesystem=home
```

If all goes fine flatpak generates an application metadata file
in ../build.vim for us. Before exporting our application in the
repository we should take a look at this file and make any necessary
adjustments we see fit.

Let's first take a look at the content of our build directory:

```
mandark vim $ ls -Fal ../build.vim
total 24
drwxrwxr-x 5 kli kli 4096 Feb  9 20:08 ./
drwxrwxr-x 5 kli kli 4096 Feb 10 18:56 ../
drwxrwxr-x 2 kli kli 4096 Feb  9 20:05 export/
drwxrwxr-x 4 kli kli 4096 Feb  9 20:05 files/
-rw-rw-r-- 1 kli kli  167 Feb  9 20:08 metadata
drwxrwxr-x 3 kli kli 4096 Feb  9 20:02 var/
```

Next we take a peak at the metadata:

```
mandark vim $ cat ../build.vim/metadata 
[Context]
filesystems=home

[Application]
name=org.vim.vim
runtime=iot.refkit.BasePlatform/x86_64/current
sdk=iot.refkit.BaseSdk/x86_64/current
command=vim
```

Since everything looks okay, we tell flatpak to do the final pieces
of necessary processing to export vim to a flatpak repository.

```
mandark vim $ flatpak build-export --gpg-homedir=<path-to-build>/gpg --gpg-sign=refkit-image-minimal@key ../vim.flatpak ../build.vim
Commit: f15cb7341253a597536c16bfa2f219731eb8451e826f9527c8dc68e94db208e5
Metadata Total: 289
Metadata Written: 128
Content Total: 1741
Content Written: 1637
Content Bytes Written: 28595251 (28.6 MB)
```

As you can see, we provided flatpak with a GPG keyring (in the given
GPG home directory) and a key ID to use for signing the application
repository. We used the key generated by meta-flatpak here but we
really could have used any other key of our choice.

If everything went fine, at this point we should have vim available
in a our newly built flatpak repository, ../vim.flatpak. Now, to test
our vim flatpak on the device, we need to first export our vim repository
over HTTP. For that we wnat to generate a configuration fragment for
exporting our application repositories. One easy way to do this is the
following command:

```
mandark vim $ cd ..
mandark build $ echo -e "Alias \"/apps/\" \"$(pwd)\"\n\n<Directory $(pwd)/>\n    Options Indexes FollowSymlinks\n    Require all granted\n</Directory>" > flatpak-apps.http.conf
mandark build $ cat flatpak-apps.http.conf
Alias "/apps/" "/v/src/users/kli/work/IoT/refkit/intel-iot-refkit/build/"

<Directory /v/src/users/kli/work/IoT/refkit/intel-iot-refkit/build/>
    Options Indexes FollowSymlinks
    Require all granted
</Directory>
```

Now we drop this confiuration file into our apache configuration and
restart it. For my distro of choice this can be done with the following:

```
mandark build $ sudo cp flatpak-apps.http.conf /etc/httpd/conf.d
mandark build $ sudo systemctl restart httpd
```

Next we need to boot up our test image with qemu. Before doing so, it
might be a good idea to give qemu a slightly more generous amount of
memory than the default 256 M. This can be done with the following
commands:

```
mandark build $ sed -e 's/-m 256/-m 1024/' -i tmp-glibc/deploy/images/qemux86-64/refkit-image-minimal-flatpak-runtime-qemux86-64.qemuboot.conf
```

Once done, we can start our runtime image in qemu:

```
mandark build $ runqemu tmp-glibc/deploy/images/qemux86-64/refkit-image-minimal-flatpak-runtime-qemux86-64.qemuboot.conf 
```

This should boot the image in qemu and leave us with an emulated console
with an automaically logged in root shell (and this is why you should use
the debug-tweak feature only in your fully controlled and trusted development
environment).

By default qemu uses a tap interface configured with 192.168.7.1 for the
local end and 192.168.7.2 for the emulated host end. Hence, you should now
be able to also log in to your qemu instance using ssh with the following
command:

```
mandark build $ ssh root@192.168.7.2
Last login: Fri Feb 10 17:32:37 2017
************************************
*** This is a development image! ***
*** Do not use in production.    ***
************************************
root@qemux86-64:~#
```

If this works, copy the public key matching the private key you used to
sign our vim flatpak repository.

```
mandark build $ scp refkit-signing.pub root@192.168.7.2:
```

Let the runtime image know about our repository:

```
mandark build $ ssh root@192.168.7.2
Last login: Fri Feb 10 17:32:37 2017
************************************
*** This is a development image! ***
*** Do not use in production.    ***
************************************
root@qemux86-64:~# flatpak remote-add test --gpg-import=refkit-signing.pub
http://192.168.7.1/apps/vim.flatpak
root@qemux86-64:~# flatpak remote-ls -d test
app/org.vim.vim/x86_64/master f15cb7341253
```

If all went fine and you were able to list the applications, you can now
install vim as a flatpak:

```
root@qemux86-64:~# flatpak install test org.vim.vim
Installing: org.vim.vim/x86_64/master from test

131 metadata, 1637 content objects fetched; 10253 KiB transferred in 23 seconds 
root@qemux86-64:~# flatpak list -d
org.vim.vim/x86_64/master test f15cb7341253 - 29.4 MB system,current 
```

And finally, if everything went ok we should be able to test our vim
flatpak:

```
root@qemux86-64:~# flatpak run org.vim.vim test-file
...edit and save something in the file...
root@qemux86-64:~# cat test-file 
The quick brown fox jumps over the lazy dog.
```

And that's it. If all this worked so far you're image is flatpak-enabled.
It can pull in software from remote flatpak repositories, and you can
build flatpak SDK runtimes which you can use to compile software and
export it to flatpak repositories to be consumed by devices running a
flatpak-enabled image.

## Testing Flatpak-Based Application Support

In addition to the functionality directly offered by flatpak, meta-flatpak
offers additional functionality, generally referred to as *'support for
flatpak-based 3rd-party applications'*.

In practice, this means a few conventions and a small daemon that uses
*libflatpak*. The conventions in the current model/setup dictate that
applications from a single provider are

 * published in a dedicated per-provider remote
 * associated with a dedicated per-provider system user, and
 * run in an automatically created seatless session for this user

The daemons task is to 

 * monitor dedicated flatpak remotes,
 * install flatpak applications from these remotes,
 * pull in any available updates for installed applications, and
 * arrange for the applications to be started during system boot

Additionally, meta-flatpak offers a mechanism for pre-declaring a set of
repositories for the images built. Devices running these images should
start pulling in and running applications from these repositories without
futher manual interventions.

meta-flatpak/flatpak-session defines a few additional pieces of possible
flatpak metadata flatpak 3-rd party applications. These are:

 * X-Install (boolean): whether the application should be autoinstalled
 * X-Start (boolean): whether the application should be autostarted
 * X-Urgency (string): how urgent an update is, 'critical', 'important'

These keys should be in the *Application* section of the metadata file.
You should tag applications that should be automatically installed and
started in the dedicated users' session with *X-Install=yes*, and
*X-Start=yes*. While currently these are the defaults in the absence of
these keys, the defaults might change in the future. Explicitly stating
these among the metadata prevents changes to the defaults from affecting
the exhibited behavior.

To test this functionality, we will

 * modify our configuration to pre-populate the image with 3 repositories
 * publish a dummy test application in these repositories
 * boot into our newly built image to check that the apps get pulled in and run

First, let's modify our configuration and declare 3 remotes/repositories.
Declaring a remote happens by

 * listing the remote name in the variable *FLATPAK_APP_REPOS*,
 * providing the key and URL in <r>.key and <r>.url in *${TOPDIR}/conf*, and
 * providing passwd and group entries for the users in *${TOPDIR}/conf/flatpak-{passwd,group}*


We'll call our remotes/repositories in an unimaginative way simply *test1*,
*test2*, and *test3*. Let's declare these now in local.conf:

```
mandark build $ echo "FLATPAK_APP_REPOS=\"test1 test2 test3\"" >> conf/local.conf
```

We'll also call the associated system users simply *test1*, *test2*, and
*test3*. Let's create the necessary passwd and group fragments for these:

```
mandark build $ cat conf/flatpak-passwd
test1:x:2000:2000:flatpak user for test1:/home/test1:/bin/sh
test2:x:2001:2001:flatpak user for test2:/home/test2:/bin/sh
test3:x:2002:2002:flatpak user for test3:/home/test3:/bin/sh

mandark build $ cat conf/flatpak-group
test1:x:2000:
test2:x:2001:
test3:x:2002:
```

Note that we created the entries with GECOs matching our association criteria
for flatpak-session. Let's now add key and URL files for these remotes. For
simplicity, we'll reuse the key we generated for our SDK image repo earlier:

```
mandark build $ for i in 1 2 3; do cp refkit-signing.pub conf/test$i.key; done

mandark build $ cat conf/test1.url
http://192.168.7.1/apps/test1

mandark build $ cat conf/test2.url
http://192.168.7.1/apps/test2

mandark build $ cat conf/test3.url
http://192.168.7.1/apps/test3
```

Next we rebuild our images, this time with information about these predefined
repositories included:

```
mandark build $ bitbake refkit-image-minimal-flatpak-runtime
```

Once the image is built, we check that the necessary bits did make it into
the image:

```
mandark build $ ls -ls tmp-glibc/work/qemux86_64-refkit-linux/refkit-image-minimal-flatpak-runtime/1.0-r0/rootfs/etc/flatpak-session
drwxr-xr-x  2 kli kli 4096 Feb 14 15:42 ./
drwxr-xr-x 24 kli kli 4096 Feb 14 16:53 ../
-rw-r--r--  1 kli kli 1187 Feb 14 15:42 test1.key
-rw-r--r--  1 kli kli   37 Feb 14 15:42 test1.url
-rw-r--r--  1 kli kli 1187 Feb 14 15:42 test2.key
-rw-r--r--  1 kli kli   37 Feb 14 15:42 test2.url
-rw-r--r--  1 kli kli 1187 Feb 14 15:42 test3.key
-rw-r--r--  1 kli kli   37 Feb 14 15:42 test3.url

mandark build $ grep test. tmp-glibc/work/qemux86_64-refkit-linux/refkit-image-minimal-flatpak-runtime/1.0-r0/rootfs/etc/passwd
test1:x:2000:2000:flatpak user for test1:/home/test1:/bin/sh
test2:x:2001:2001:flatpak user for test2:/home/test2:/bin/sh
test3:x:2002:2002:flatpak user for test3:/home/test3:/bin/sh

mandark build $ grep test. tmp-glibc/work/qemux86_64-refkit-linux/refkit-image-minimal-flatpak-runtime/1.0-r0/rootfs/etc/group
test1:x:2000:
test2:x:2001:
test3:x:2002:
```

Next we need to create flatpak repositories for these remotes and populate
them with at least 1 application per repository. We'll do this by cloning
a dummy test application and flatpak-building it 3 times for the 3 different
repos with slightly different command line argument so that we'll be able
to tell from the logs/systemd journal if each of them is running.

Let's first clone the dummy code:

```
mandark build $ mkdir app-build
mandark build $ cd app-build
mandark app-build $ git clone https://github.com/klihub/dummy-test.git
```

Now let's flatpak-build the application 3 times:

```
mandark app-builds $ for i in test1 test2 test3; do mkdir build.dummy-test.$i; done
mandark app-builds $ for i in test1 test2 test3; do flatpak build-init build.dummy-test.$i org.$i.dummy iot.refkit.BaseSdk iot.refkit.BasePlatform current; done
mandark app-builds $ cd dummy-test
mandark dummy-test $ for i in test1 test2 test3; do flatpak build ../build.dummy-test.$i ./configure --prefix=/app; flatpak build ../build.dummy-test.$i make; flatpak build ../build.dummy-test.$i make install; done
/bin/sh: warning: setlocale: LC_ALL: cannot change locale (en_US.utf8)
checking for a BSD-compatible install... /usr/bin/install -c
checking whether build environment is sane... yes
checking for a thread-safe mkdir -p... ./install-sh -c -d
checking for gawk... gawk
checking whether make sets $(MAKE)... yes
checking whether make supports nested variables... yes
checking for gcc... gcc
checking whether the C compiler works... yes
...
```

Let's finalize the builds for our applications and update their metadata.

```
mandark dummy-test $ for i in test1 test2 test3; do flatpak build-finish ../build.dummy-test.$i --command="dummy-test $i"; done
Please review the exported files and the metadata
Please review the exported files and the metadata
Please review the exported files and the metadata
mandark dummy-test $ for i in test1 test2 test3; do echo -e "X-Install=yes\nX-Start=yes\n" >> ../build.dummy-test.$i/metadata; done
mandark dummy-test $ for i in test1 test2 test3; do cat../build.dummy-test.$i/metadata; done
[Application]
name=org.test1.dummy
runtime=iot.refkit.BasePlatform/x86_64/current
sdk=iot.refkit.BaseSdk/x86_64/current
command=dummy-test test1
X-Install=yes
X-Start=yes

[Application]
name=org.test2.dummy
runtime=iot.refkit.BasePlatform/x86_64/current
sdk=iot.refkit.BaseSdk/x86_64/current
command=dummy-test test2
X-Install=yes
X-Start=yes

[Application]
name=org.test3.dummy
runtime=iot.refkit.BasePlatform/x86_64/current
sdk=iot.refkit.BaseSdk/x86_64/current
command=dummy-test test3
X-Install=yes
X-Start=yes

```

Since everything looks good, let's create the repositories and export the
applications:

```
mandark dummy-test $ for i in test1 test2 test3; do flatpak build-export --gpg-homedir=../../gpg --gpg-sign=refkit-image-minimal@key ../$i.flatpak ../build.dummy-test.$i; done
Commit: cb440db279ced372a9fa428dbe1e9808f43b10a41b8560d05fc2c6efeed73334
Metadata Total: 9
Metadata Written: 1
Content Total: 2
Content Written: 0
Content Bytes Written: 0 (0 bytes)
Commit: f84ec77a3babfa1f87f97a499c3781e8e8e39ea633795287a2bc9b6cea46796d
Metadata Total: 9
Metadata Written: 1
Content Total: 2
Content Written: 0
Content Bytes Written: 0 (0 bytes)
Commit: 57fcece02a087da2e5648bf78848d3f07d90910fd262e96b015caafc20012677
Metadata Total: 9
Metadata Written: 1
Content Total: 2
Content Written: 0
Content Bytes Written: 0 (0 bytes)
```

Now, the final thing on the host side is to export these repositories over
HTTP for consumption by the clients. For this we'll generate 3 apache2
configuration fragments, one for each remote.

```
cd ..
mandark app-builds $ for i in test1 test2 test3; do cat flatpak-apps-$i.conf; done
Alias "/apps/test1" "/home/kli/src/work/IoT/refkit/app-builds/test1.flatpak/"

<Directory /home/kli/src/work/IoT/refkit/app-builds/test1.flatpak/>
    Options Indexes FollowSymlinks
    Require all granted
</Directory>

Alias "/apps/test2" "/home/kli/src/work/IoT/refkit/app-builds/test2.flatpak/"

<Directory /home/kli/src/work/IoT/refkit/app-builds/test2.flatpak/>
    Options Indexes FollowSymlinks
    Require all granted
</Directory>
Alias "/apps/test3" "/home/kli/src/work/IoT/refkit/app-builds/test3.flatpak/"

<Directory /home/kli/src/work/IoT/refkit/app-builds/test3.flatpak/>
    Options Indexes FollowSymlinks
    Require all granted
</Directory>
```

If all look ok, we copy them in place, and restart our HTTP server:

```
mandark app-builds $ sudo cp -v flatpak-apps-test?.conf /etc/httpd/conf.d
'flatpak-apps-test3.conf' -> '/etc/httpd/conf.d/flatpak-apps-test3.conf'
'flatpak-apps-test3.conf' -> '/etc/httpd/conf.d/flatpak-apps-test3.conf'
'flatpak-apps-test3.conf' -> '/etc/httpd/conf.d/flatpak-apps-test3.conf'

mandark app-builds $ sudo systemctl restart httpd
```

To verify that everything works as expected, the one remaining thing
is to boot our image and verify that eventually the applications get
pulled in and started.

```
mandark app-builds $ cd ..
mandark build $ sed -e 's/-m 256/-m 1024/' -i tmp-glibc/deploy/images/qemux86-64/refkit-image-minimal-flatpak-runtime-qemux86-64.qemuboot.conf
mandark build $ runqemu tmp-glibc/deploy/images/qemux86-64/refkit-image-minimal-flatpak-runtime-qemux86-64.qemuboot.conf
```

Once the image has booted, clear the entry from .ssh/known_hosts and
log in with ssh:

```
mandark build $ sed -e 's/^.*192.168.7.2 .*$//g' -i ~/.ssh/known_hosts
mandark build $ ssh root@192.168.7.2
Last login: Fri Feb 10 17:32:37 2017
************************************
*** This is a development image! ***
*** Do not use in production.    ***
************************************
root@qemux86-64:~# 
```

Let's check the process list and logs:

```
root@qemux86-64:~# ps | grep "dummy-test test"
...
  755 test1     8380 S    dummy-test test1
  756 test3     8380 S    dummy-test test3
  757 test2     8380 S    dummy-test test2
  797 root      7848 S    grep dummy-test test
root@qemux86-64:~# journalctl -a | grep flatpak-session
...
Feb 15 15:41:38 qemux86-64 flatpak-session[537]: I: flatpak: starting application org.test.test2
Feb 15 15:41:38 qemux86-64 dbus-daemon[630]: Activating via systemd: service name='org.freedesktop.Flatpak' unit='flatpak-session-helper.service'
Feb 15 15:41:38 qemux86-64 dbus-daemon[631]: Activating via systemd: service name='org.freedesktop.Flatpak' unit='flatpak-session-helper.service'
Feb 15 15:41:38 qemux86-64 dbus-daemon[633]: Activating via systemd: service name='org.freedesktop.Flatpak' unit='flatpak-session-helper.service'
Feb 15 15:41:42 qemux86-64 flatpak-session[536]: I: flatpak: starting application org.test1.dummy
Feb 15 15:41:42 qemux86-64 flatpak-session[538]: I: flatpak: starting application org.test3.dummy
Feb 15 15:41:42 qemux86-64 flatpak-session[537]: I: flatpak: starting application org.test2.dummy
Feb 15 15:41:45 qemux86-64 flatpak-session[538]: <test3 (dummy-test): user 2002/test3> iteration #0
Feb 15 15:41:45 qemux86-64 flatpak-session[536]: <test1 (dummy-test): user 2000/test1> iteration #0
Feb 15 15:41:45 qemux86-64 flatpak-session[537]: <test2 (dummy-test): user 2001/test2> iteration #0
Feb 15 15:41:46 qemux86-64 flatpak-session[536]: <test1 (dummy-test): user 2000/test1> iteration #0
Feb 15 15:41:46 qemux86-64 flatpak-session[538]: <test3 (dummy-test): user 2002/test3> iteration #0
Feb 15 15:41:46 qemux86-64 flatpak-session[537]: <test2 (dummy-test): user 2001/test2> iteration #0
Feb 15 15:42:15 qemux86-64 flatpak-session[538]: <test3 (dummy-test): user 2002/test3> iteration #1
Feb 15 15:42:15 qemux86-64 flatpak-session[536]: <test1 (dummy-test): user 2000/test1> iteration #1
Feb 15 15:42:15 qemux86-64 flatpak-session[537]: <test2 (dummy-test): user 2001/test2> iteration #1
Feb 15 15:42:16 qemux86-64 flatpak-session[536]: <test1 (dummy-test): user 2000/test1> iteration #1
Feb 15 15:42:16 qemux86-64 flatpak-session[538]: <test3 (dummy-test): user 2002/test3> iteration #1
Feb 15 15:42:16 qemux86-64 flatpak-session[537]: <test2 (dummy-test): user 2001/test2> iteration #1
...
```

If your output looks similar enough, your image took the pre-defined remotes
in use, discovered and installed the applications in them, and started them
up.
