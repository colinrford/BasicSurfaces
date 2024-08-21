# BasicSurfaces

![Rotating Sphere Demo](/rotating-sphere-xcode-preview.gif)

This repo serves as a proof-of-concept of using Metal to render graphics inside a SwiftUI `View`, which among other things allows for `Metal View`s (see MetalUI, either in this repository, or [here](https://github.com/colinrford/MetalUI)) to work inside Xcode previews. 

As of now this should just be `git clone`-able and build just fine right out of the box. Since this was refactored from an older project with the same name, **there may be strange build bugs**. An example of one – the only one I've encountered – is that I can successfully preview this in Xcode with the target set to 'My Mac', but it fails when I set the target to 'My Mac (Mac Catalyst).' I figured a switch like this would be fine since it seems to build fine for iPhone (simulator & real). Hopefully this is something relatively easy to figure out and I can update accordingly (and hopefully not too embarrassing!!). Another quick caveat: the aspect ratio is fixed (I know, embarrassing!!!). Maybe I'll be not terribly lazy and address that.

For now I intend to keep this minimal, and really just keep it a proof-of-concept. Perhaps if there is interest I will expand upon it in the future.
