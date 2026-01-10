# Assist MuvLuv

## The Game(s)

### マブラヴ ガールズガーデン (MuvLuv GirlsGarden)

Assume the game(s) is/are played on the dmm games player.

When playing this game and farming the "メイズ探索", my phone heats and the
battery drains, which is the reason why the script(s) was/were written as I was
using [Klick'r](https://github.com/Nain57/Smart-AutoClicker)
to automate gacha games on Android, but later I do not play them too much
since I have sensed it's the media art appearance of them that makes
distractions to me rather than their game system and forms interesting me.

In game system, they are just leisures and well organized presentations where
the same operations and decision-making forms inside. Maybe the repeating
is the game itself in most cases such as life but if so where the reincarnation
happens? Wired.

## The Script(s)

The script(s) can be directly ran by
[AutoIt](https://www.autoitscript.com/site/), an automation software on
Windows. And there are some OpenCV-related files with
thanks to the implementation of
[AutoIt-OpenCV-COM](https://github.com/smbape/node-autoit-opencv-com).

The algorithm of finding template in OpenCV is based on the covariance of two
images by default so if the original image is averagely changed like changing
lightness it would be still matched as the covariance is not changed too much.
The complexity of it is the multiply of the pixels of the two images
respectively. The implementation of it works on CPU.

I initially tried to use [AutoHotkey](https://www.autohotkey.com/), but the
function "ImageSearch" in its library is too simple to search image. After
getting my hands dirty for days, I got this solution. Because the farming has
been finished, this repository will not be updated anymore.

But there may be some more decent softwares that implement the behaviors in
the script(s), and may have interface to capture image, edit image, set logic,
set operations, etc. Like
[Klick'r](https://github.com/Nain57/Smart-AutoClicker) on Android.

However, the script(s) has/have been written anyway. Who cares.

## The Assist

Mainly the assist aims to do the repeating operations in some scenarios.
There aren't much detailed words to describe this assist. Make sure the game
window is resized to 1280x720 by
[SmartSystemMenu](https://github.com/AlexanderPro/SmartSystemMenu)
making the game window size 1264x712.

Repeating operations scenarios:

1. Consecutive 5 battles in story or event (not the event of new story
episode) (メインストーリー／イベント). Repeat clicking
"quest enter", "battle enter", "skip" and "next".
The assist running will be stopped when entering to an adv scene.

2. Battle Simulation (バトルシミュレーション). Repeat clicking
"room enter", "battle enter", "skip" and "next".
The assist running will be stopped when a battle fails and it is as-is in other
scenarios.

3. Maze exploration (メイズ探索). Repeat clicking
"maze enter", "team makeup done", "skip", "route select", "select helper",
"leave (mid-shop)", "done (when final shop costs all stones)".
If there are no errors to happen this scenario will be repeated endlessly if
the daily things buying limit is reached.
When the maze farming is checked, the assist will auto buying other things at
the end of a maze exploration loop.

4. Tactical Exercise (戦術演習). It has the same button as battle simulation.

Basically, the script(s) just implement(s) clicking a image, so the scenarios
above are ideal situations.

## Notes

I use [ShareX](https://getsharex.com/) to capture the game window and use
[ImageGlass](https://imageglass.org/) to crop the image and get the rect of
area for template images.

The images in the directory "Games" are captured from its game. Their relative
area rectangle infos are hard coded in the script(s) while the directory
"Games/Irismysteria" is not used.

The directory "Libs" has [OpenCV4120](https://github.com/opencv/opencv) lib
and the corresponding
[AutoIt-OpenCV-COM](https://github.com/smbape/node-autoit-opencv-com) libs.

The "Patak.jpg" in the directory "Res" is a wallpaper from KDE plasma. It can
be found in
[plasma workspaces wallpapers](https://github.com/KDE/plasma-workspace-wallpapers).

The script "Test_OpenCV.au3" is a modified example from one of samples in
[AutoIt-OpenCV-COM](https://github.com/smbape/node-autoit-opencv-com).
