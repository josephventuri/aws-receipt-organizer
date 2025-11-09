from PIL import Image, ImageDraw, ImageFont

def create_icon(size, filename):
    # Create image with gradient-like solid color
    img = Image.new('RGB', (size, size), color='#667eea')
    draw = ImageDraw.Draw(img)

    # Draw a simple receipt icon representation
    # Background gradient simulation
    for y in range(size):
        r = int(102 + (118 - 102) * y / size)
        g = int(126 + (75 - 126) * y / size)
        b = int(234 + (162 - 234) * y / size)
        draw.line([(0, y), (size, y)], fill=(r, g, b))

    # Draw a simple receipt shape
    margin = size // 4
    rect_top = margin
    rect_bottom = size - margin
    rect_left = margin
    rect_right = size - margin

    # White rectangle for receipt
    draw.rounded_rectangle(
        [rect_left, rect_top, rect_right, rect_bottom],
        radius=size // 20,
        fill='white'
    )

    # Draw some lines to represent text on receipt
    line_margin = margin + size // 10
    line_spacing = size // 15
    for i in range(3):
        y = rect_top + margin // 2 + i * line_spacing
        draw.line(
            [(line_margin, y), (rect_right - margin // 2, y)],
            fill='#667eea',
            width=size // 50
        )

    # Save
    img.save(f'frontend/{filename}')
    print(f'Created {filename}')

# Generate icons
create_icon(192, 'icon-192.png')
create_icon(512, 'icon-512.png')
print('Icons created successfully!')
