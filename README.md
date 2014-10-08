git-diff-popup
==========

**An Atom editor package to easily show one Git difference in a small pop-up.**

  ![Animated GIF](https://github.com/mark-hahn/git-diff-popup/blob/master/screenshots/diff.gif?raw=true)

---

## Details

Git-Diff-Popup (GDP) allows you to view a text difference from the Git repository head in a small pop-up without adding or changing tabs.  A difference is one or more adjacent changed lines, commonly known as a chunk.  The pop-up shows the old version.  At the top of the pop-up are buttons that allow you to copy the changes to the clipboard or revert the changes, each in one click.  GDP enables a fast intuitive workflow when retrieving or comparing versions of localized text.  

GDP also supports the Live-Archive package version storage.  See the *Live Archive* Section below.

## Installation

Use the normal `apm install Git-Diff-Popup` command or use the packages section of settings.

## Usage

The following instructions assume Live-Archive is not installed. If it is then there will be slightly different instructions. See the *Live Archive* section below for these differences.

There is one command `git-diff-popup:toggle` which is installed by default with the binding `ctrl-alt-D`. Make sure the cursor is on a changed line (in a difference chunk) and then execute the command. Two things will happen.  The entire chunk of lines will be selected and a pop-up will appear next to that selection with the old version from the Git repository head.

Note that you do not click in the gutter but on the actual text to make the selection. If the cursor is not on a changed line then a warning will be given.  In order to select a deletion place the cursor on a line before or after the deletion.

Once the pop-up is shown you can ...

- Copy text from the read-only pop-up to paste in your text.
- Change tabs and even edit text while the non-modal pop-up stays up.
- Drag the pop-up around to reveal text underneath.
- Click on the copy-all button which places all lines in the clipboard. The pop-up will close.
- Click on the revert button to replace the selected text with the old version. The pop-up will close. (You may undo the revert).
- Close the pop-up by clicking on the Close button, pressing escape, or pressing `ctrl-alt-D` again.

## Live Archive

If the Live-Archive package, available at https://atom.io/packages/live-archive, is installed then Git-Diff-Popup can access old text versions from both Git and/or the Live Archive.
 
The Live Archive holds a compressed snapshot of every save of every file in a package.  Normally when using the Live Archive you access old versions as complete files in separate tabs.  GDP offers the faster simpler pop-up.

  ![Animated GIF](https://github.com/mark-hahn/git-diff-popup/blob/master/screenshots/diffla.gif?raw=true)

**Live-Archive Advantages:**

- It supports many more versions than Git
- It has more flexible selections with GDP than Git.  You can select any set of lines, not just difference chunks.
- It has navigation arrows to travel through time.


**Shameless plug:**  The Atom blog called Live-Archive an *"amazing feature-packed package which provides VCR-like controls for inspecting previous versions of files and their diffing."*  Now GDP adds the simpler pop-up.

## Live Archive Usage

Git-Diff-Popup chooses the Git repository or the Live Archive based on how text is selected when the command (`ctrl-alt-D`) is given.  In order to use Git you must make sure the cursor is on a changed line and you must have no selection, i.e. just the cursor. If there is a selection of one or more characters then the lines selected will be looked up in the Live Archive instead of the Git repository.

When GDP is using Git there will be a Git icon at the top. When GDP uses the Live Archive there will instead be a faint version number such as `v7` to the left of the buttons.  `v1` is the newest version, `v2` is the next older one, etc.  There will also be left/right arrow buttons to navigate between versions.


## Acknowledgement

Git-Diff-Popup was inspired by a similar feature found in JetBrains IDE software.

## License

Git-Diff-Popup is copyright Mark Hahn under the MIT license.  See `LICENSE.md`.

