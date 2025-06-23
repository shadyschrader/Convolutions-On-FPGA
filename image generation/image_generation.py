import numpy as np

# Generate 128x128 = 16384 random 8-bit values
data = np.random.randint(0, 256, size=(128 * 128), dtype=np.uint8)

# Create the .coe content
with open("image_data.coe", "w") as f:
    f.write("memory_initialization_radix=16;\n")
    f.write("memory_initialization_vector=\n")
    for i, value in enumerate(data):
        # Write the value in 2-digit hex
        if i == len(data) - 1:
            f.write(f"{value:02X};\n")  # End with semicolon
        else:
            f.write(f"{value:02X},\n")
