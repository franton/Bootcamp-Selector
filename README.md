# Bootcamp-Selector
Script to be run as part of your Casper bootstrapping workflows to install a specific bootcamp image to a computer.

Thanks to Apple continually updating Bootcamp versions, never having a generic driver installer and more recently with the 2015 Macs changing the supported disk sector size from 512 to 4096 it's never been harder to generate deployable Bootcamp images.

See this : http://blog.twocanoes.com/post/119029974198/winclone-image-compatibility-with-512-and-4k-block

Short version is 2015 mac generated images only work on 2015 macs. Images from 2014 macs don't work on 2015 macs and then you have to mix in all the different bootcamp versions. Now Tim Sutton has done wonders with his Brigadier tool. I've used it myself and found it very good. However my current circumstances don't allow it's use since we still have 32bit machines (!) here.

--

A thorny problem indeed. Unfortunately that means separate images which is the admin's worst nightmare. While I can't do much about the generation of those images, I can hopefully make their deployment a lot easier. To do that, you'll need the following:

1. This script
2. Winclone 5 or better. (At time of writing, 5 is the latest version)
3. Casper (although this could be modified to work on other systems. DeployStudio coming maybe soon?)

What this script will do is detect if you have a bootcamp partition present, your computer's Model Identifier, cache the appropriate image onto the system, install it and then rename it so it has the same hostname as your OS X installation but with "PC-" appended in front of it.

Setting up

1. Prepare your deployment workflows in Casper so that it creates a blank NTFS partition on the boot drive as partition 4.
(that's right, get Casper not Winclone to do the partitioning work).
2. Prepare your Winclone images so that they are self extracting and pkg installers.
3. It is essential that you set the pkgs to deploy to partition 4. (Unless you're removing the Recovery partition, then partition 3
4. Name your images something useful. In the script i've got them named as "Win7-5-64bit".
5. Upload the completed pkg's to Casper. You may have to zip them up first if Casper doesn't do that for you already.
6. Create a new Casper category called "Bootcamp Images". This step isn't strictly necessary but it does keep the place tidy.
7. Create a policy to deploy the first of your Bootcamp images.
This should be set to run every time and only on a manual trigger.
The trigger should be set to the same name as in step 4.
Set this policy to cache the Bootcamp image to the computer.
8. Add this script to your Bootstrapping policies. Don't worry, if a Bootcamp partition doesn't exist then it will quit gracefully.

We're relying on Twocanoe's work to actually do the image deployment through the scripts embedded in the pkg, which should handle all the MBR / EFI boot stuff. That makes our task easier, and why re-invent the wheel?
