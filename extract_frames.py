import av
import os
import csv
import argparse
import sys

def extract_frames(video_path, output_folder):
    """
    Extracts frames from a video file and saves them as images, along with a CSV mapping filenames to timestamps.

    This function reads a video file, extracts each frame, and saves it as a JPEG image in the specified
    output directory. It also looks for a 'video_start_time.txt' file in the same directory as the video
    to determine the absolute start time offset. If found, this offset is added to the relative video
    timestamps. A CSV file 'frame_timestamps.csv' is created in the output directory, containing
    'filename' and 'timestamp' columns.

    Args:
        video_path (str): The file path to the input video (e.g., .mov, .mp4).
        output_folder (str): The directory where extracted images and the CSV file will be saved.
                             The directory will be created if it does not exist.

    Returns:
        None
    """
    # Create output directory
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    # Open the video file
    try:
        container = av.open(video_path)
    except Exception as e:
        print(f"Error opening video file: {e}")
        return

    if not container.streams.video:
        print("No video stream found in file.")
        return

    stream = container.streams.video[0]
    
    # Try to find the start time offset
    video_dir = os.path.dirname(video_path)
    start_time_path = os.path.join(video_dir, "video_start_time.txt")
    start_offset = 0.0
    
    if os.path.exists(start_time_path):
        try:
            with open(start_time_path, 'r') as f:
                content = f.read().strip()
                start_offset = float(content)
            print(f"Found start time offset: {start_offset}")
        except ValueError:
            print("Warning: Could not parse video_start_time.txt")
    else:
        print("Warning: video_start_time.txt not found. Timestamps will be relative to 0.")

    # Prepare CSV to link filename -> timestamp
    csv_path = os.path.join(output_folder, "frame_timestamps.csv")
    
    print(f"Processing: {video_path}")
    
    with open(csv_path, mode='w', newline='') as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(["filename", "timestamp"])

        for i, frame in enumerate(container.decode(stream)):
            # Calculate the exact timestamp in seconds
            # frame.pts is the raw integer timestamp
            # stream.time_base is the unit (e.g., 1/600)
            if frame.pts is None:
                continue
                
            # Add the start_offset to the relative video time
            timestamp_seconds = float(frame.pts * stream.time_base) + start_offset
            
            # Save Image
            filename = f"frame_{i:06d}.jpg"
            file_path = os.path.join(output_folder, filename)
            
            # Convert to PIL image and save
            frame.to_image().save(file_path)
            
            # Log to CSV
            writer.writerow([filename, f"{timestamp_seconds:.6f}"])
            
            if i % 50 == 0:
                print(f"Saved {filename} at t={timestamp_seconds:.6f}")

    print(f"Done! Frames and CSV saved to {output_folder}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract frames from a video file with timestamps.")
    parser.add_argument("video_path", help="Path to the input video file")
    parser.add_argument("output_folder", help="Path to the output folder for frames and CSV")
    
    args = parser.parse_args()
    
    extract_frames(args.video_path, args.output_folder)