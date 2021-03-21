# Form From Functions

Form From Functions (aka FFF or 3F) is a (very) work-in-progress VR visual programming environment to allow anyone to write code within VR by manipulating objects in virtual space. 

The goal is to make the programming environment itself customizable with code written in VR so that multiple interaction models can be tested and interchanged without having to take off the headset.

## Current status and roadmap

Currently, FFF is in the bare proof-of-concept stage and has only been tested on the Oculus Quest 1. The following things currently work in some capacity:

- Hand display in the form of white spheres at their position
- Blocks that can contain text but do not size to their contents
- Linking blocks works, but not in a way that helps prevent syntax errors; it's just as prone to error as linear code
- Text input via arcade-style input
- Compilation and evaluation of code written in VR works, but only if the code to be evaluated is linked from the first block

Which is *just* enough to actually write some code within VR, but doesn't make it pleasant. Some things that need to happen to take this from proof-of-concept to
viable are:

- Snapping blocks together, and snapping inside of boxes/block containers so that code has a natural, non-stringy shape and is easier to read
- Relative grabbing of blocks and boxes so that it's easier to precisely place them
- Rotation of blocks so that you can surround yourself with code and not have to read it backwards
- Locomotion and teleportation so that programming can be done in a full virtual space instead of being confined to the size of your playspace
- Implementation of layers and overlays so that multiple modules can co-exist and be swapped between

Some ideas for the future:

- A symbol keyboard that provides symbols from your environment as buttons you can press to create new blocks, avoiding the need to type every box out
- The ability to open a portal to other code, allowing you to see code you'd like to reference

## Running it

Currently this only builds on Windows and has only been tested on a Quest 1. However, you can try to run it on other platforms, but adapters for those controllers have not been written so you may not be able to do much.

```bash
make
```

Then [copy all the lua files and directories containing lua files onto the headset to run via LÖVR](https://lovr.org/docs/Getting_Started_(Android)).

## Implementation

FFF is written in [Fennel](https://fennel-lang.org/), a lisp that compiles to Lua. It was chosen because lisps have very little syntax (so it's easy to make a visual editor for it) and it is completely self-hosted so that the compiler can be run within a plain lua environment.

[LÖVR](https://lovr.org/) is a relatively low-level lua framework for writing VR applications, much like it's 2D sibling [LÖVE](https://love2d.org/). It was chosen because its familiar (similar to LÖVE) and it was immediately obvious how to write, compile, and run code within it as opposed to Entity-Component-System-like (Unity-like) or inheritance based (Godot-like) systems.