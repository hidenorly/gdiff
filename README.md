# gdiff

This is binary supported diff which utilizes ```git``` command.

```
Usage: sourceDir targetDir -p patchOutputDir
    -v, --verbose                    Enable verbose status output (default:false)
    -p, --patch=                     Specify patch output directory (default:.)
    -x, --exclude=                   Specify exclude filter (default:.git|.DS_Store)
```

```
$ ./gdiff.rb source dest -p outputPath -x ".git|.rb|.js"
```

You can apply the generated patch by ```git apply 0001.patch```
