zig build -Dtarget=arm-freestanding-eabihf -Dcpu=cortex_m33
cp zig-out/lib/libzig-learning.a ../firefly-firmware/