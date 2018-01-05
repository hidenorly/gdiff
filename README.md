# gdiff

This is binary supported diff which utilizes ```git``` command.

```
Usage: -s sourceDir -t targetDir -p patchOutputDir
    -v, --verbose                    Enable verbose status output (default:false)
    -s, --source=                    Specify source path
    -t, --destination=               Specify destination path
    -p, --patch=                     Specify patch output directory (default:.)
    -x, --exclude=                   Specify exclude filter (default:.git|.DS_Store)
```

```
$ ./gdiff.rb -s source -t dest -p outputPath -x ".git|.rb|.js"
```

You can apply the generated patch by ```git apply 0001.patch```
