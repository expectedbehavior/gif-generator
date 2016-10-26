require 'rmagick'

HEIGHT_WIDTH_RATIO = 300/187.to_f
OVERLAP_WIDTH = 1

image_list = Magick::ImageList.new
base_colors_image = Magick::Image.read("base-images/base-colors.gif").first
base_images = {}
screenshots = {}
new_images = {}
Dir.glob('base-images/banner*.png') do |base_image|
  puts base_image
  base_images[base_image] = Magick::Image.read("#{base_image}").first
  # Sketch only outputs to PNGs, not optimized gifs
  # so lets use an image optimized by Photoshop to pick the optimal color palette
  # cause I couldn't get ImageMagick to pick the best colors
  # this particular base image has 220 colors, so 37 colors left to use!

  # find boundaries of green box
  pixels = base_images[base_image].get_pixels(0,0, base_images[base_image].columns, base_images[base_image].rows)
  first_green = nil
  for y in 0..base_images[base_image].rows
    for x in 0..base_images[base_image].columns
      pixel = base_images[base_image].pixel_color(x, y)
      # / 257 converts from Quantum 16bit to Quantum 8bit, or at least that's what StackOverflow says
      # green color
      if (pixel.red / 257) == 126 && (pixel.green / 257) == 211 && (pixel.blue / 257) == 33
        unless first_green
          first_green = {:x => x, :y => y}
        end
        last_green = {:x => x, :y => y}
      end
    end
  end

  # setup
  base_images[base_image].format = "gif"
  base_images[base_image].strip! #strip metadata
  base_images[base_image] = base_images[base_image].remap(base_colors_image, Magick::NoDitherMethod)

  # make sure there's a green box
  unless first_green.nil?
    # is the green box on any edges?
    left_edge = false
    right_edge = false

    if first_green[:x] <= 1
      left_edge = true
    end
    if last_green[:x] >= base_images[base_image].columns - OVERLAP_WIDTH
      right_edge = true
    end


    # resize screenshot
    # add a couple extra pixels to make sure we cover an aliased green box
    if !left_edge && !right_edge
      # floating in center, resize based on width
      screenshot_width = (last_green[:x] - first_green[:x]) + (OVERLAP_WIDTH * 2)
      screenshot_height = screenshot_width / HEIGHT_WIDTH_RATIO
    else
      # one edge off ad, resize based on height
      screenshot_height = (last_green[:y] - first_green[:y]) + (OVERLAP_WIDTH * 2)
      screenshot_width = screenshot_height * HEIGHT_WIDTH_RATIO
    end

    # loop through all the screenshots
    Dir.glob('screenshots/*.png') do |screenshot_file|
      screenshots[screenshot_file] = Magick::Image.read("#{screenshot_file}").first
      screenshots[screenshot_file].scale!(screenshot_width, screenshot_height)

      # use the edges to determine screenshot positioning
      if left_edge && right_edge
        # center the screenshot so both sides are cropped
        x_pos = ((base_images[base_image].columns - screenshot_width) / 2) + OVERLAP_WIDTH
      elsif left_edge
        # right align screenshot so left side is cropped
        x_pos = last_green[:x] - screenshot_width + OVERLAP_WIDTH
      else
        # left align screenshot
        x_pos = first_green[:x] - OVERLAP_WIDTH
      end
      y_pos = first_green[:y] - OVERLAP_WIDTH
      new_images[screenshot_file] = base_images[base_image].composite(screenshots[screenshot_file], x_pos, y_pos, Magick::OverCompositeOp)
      image_list.push(new_images[screenshot_file])
    end

    image_list = image_list.remap(base_colors_image, Magick::NoDitherMethod)

    image_name = base_image.split("/").last.split(".").first
    # image_list.deconstruct
    image_list.write("output/#{image_name}-animated.gif")
    image_list.format = "png"
    image_list.first.write("output/#{image_name}-static.png")
    `gifsicle --loopcount=1 --delay 25 --optimize=3 output/#{image_name}-animated.gif -o output/#{image_name}-animated.gif`
    image_list.clear
  end
end
