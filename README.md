# raytracing-nim
raytracing in a weekend with nim

http://www.realtimerendering.com/raytracing/Ray%20Tracing%20in%20a%20Weekend.pdf

## Performance

After some some benchmarking, using nimprof help me find some problem with `Option[T]` return type.
Refactoring to a simple tuple `(bool, T)` resulted in a 3.5x performance improvement.

### C backend
```
raytracing-nim $ time nim c --run -f -d:nsamples=100 -d:showProgress -d:release main
...
Hint: operation successful (46999 lines compiled; 2.673 sec total; 71.785MiB peakmem; Release Build) [SuccessX]
Hint: /media/agus/3TB/agus/coding/nim/raytracing-nim/main  [Exec]
99                 
real    0m54.468s
user    0m55.465s
sys     0m0.416s
```

### C backend (multithread)

```
raytracing-nim $ time nim c --run --threads:on -f -d:nsamples=100 -d:showProgress --threadAnalysis:off -d:release main
...
Hint: operation successful (53314 lines compiled; 2.921 sec total; 72.723MiB peakmem; Release Build) [SuccessX]
Hint: /media/agus/3TB/agus/coding/nim/raytracing-nim/main  [Exec]
99                 
real    0m34.527s
user    1m9.209s
sys     0m1.572s
```

### C++ backend

```
raytracing-nim $ time nim cpp --run -f -d:nsamples=100 -d:showProgress -d:release main
...
Hint: operation successful (46999 lines compiled; 2.792 sec total; 71.875MiB peakmem; Release Build) [SuccessX]
Hint: /media/agus/3TB/agus/coding/nim/raytracing-nim/main  [Exec]
99                 
real    0m59.046s
user    1m0.203s
sys     0m0.392s
```

### C++ backend (multithread)
```
raytracing-nim $ time nim cpp --run --threads:on -f -d:nsamples=100 -d:showProgress --threadAnalysis:off -d:release main
...
Hint: operation successful (53314 lines compiled; 3.168 sec total; 72.695MiB peakmem; Release Build) [SuccessX]
Hint: /media/agus/3TB/agus/coding/nim/raytracing-nim/main  [Exec]
99                 
real    0m37.762s
user    1m15.127s
sys     0m1.783s
```

### Rust comparison (multithread)
```
rust/raytracing $ time cargo run --release
...
:: Generating the scene
:: Generating the image
:: Writing the image

real	0m32.001s
user	1m33.092s
sys	0m2.140s

```