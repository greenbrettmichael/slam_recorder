import os
import shutil
import tempfile
import av
import numpy as np
from PIL import Image
import pytest
import sys

# Add parent directory to path to import extract_frames
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from extract_frames import extract_frames

@pytest.fixture
def temp_dir():
    dir_path = tempfile.mkdtemp()
    yield dir_path
    shutil.rmtree(dir_path)

def create_dummy_video(video_path, num_frames=10, width=64, height=64):
    container = av.open(video_path, mode='w')
    stream = container.add_stream('h264', rate=30)
    stream.width = width
    stream.height = height
    stream.pix_fmt = 'yuv420p'

    for i in range(num_frames):
        # Create a dummy image
        img = Image.fromarray(np.random.randint(0, 255, (height, width, 3), dtype=np.uint8))
        frame = av.VideoFrame.from_image(img)
        for packet in stream.encode(frame):
            container.mux(packet)

    # Flush stream
    for packet in stream.encode():
        container.mux(packet)

    container.close()

def test_extract_frames(temp_dir):
    video_path = os.path.join(temp_dir, "test_video.mov")
    output_folder = os.path.join(temp_dir, "output")
    start_time_path = os.path.join(temp_dir, "video_start_time.txt")
    
    # Create dummy video
    create_dummy_video(video_path, num_frames=5)
    
    # Create start time file
    start_offset = 1000.0
    with open(start_time_path, 'w') as f:
        f.write(str(start_offset))
        
    # Run extraction
    extract_frames(video_path, output_folder)
    
    # Verify output
    assert os.path.exists(output_folder)
    assert os.path.exists(os.path.join(output_folder, "frame_timestamps.csv"))
    
    # Check frames
    for i in range(5):
        frame_name = f"frame_{i:06d}.jpg"
        assert os.path.exists(os.path.join(output_folder, frame_name))
        
    # Check CSV content
    with open(os.path.join(output_folder, "frame_timestamps.csv"), 'r') as f:
        lines = f.readlines()
        assert len(lines) == 6 # Header + 5 frames
        header = lines[0].strip().split(',')
        assert header == ["filename", "timestamp"]
        
        first_row = lines[1].strip().split(',')
        assert first_row[0] == "frame_000000.jpg"
        # Timestamp should be close to start_offset (0 + 1000.0)
        # Note: encoding/decoding might introduce slight shifts, but for generated frames it should be very close
        assert float(first_row[1]) >= start_offset

def test_extract_frames_no_start_time(temp_dir):
    video_path = os.path.join(temp_dir, "test_video_no_start.mov")
    output_folder = os.path.join(temp_dir, "output_no_start")
    
    # Create dummy video
    create_dummy_video(video_path, num_frames=3)
    
    # Run extraction (without creating video_start_time.txt)
    extract_frames(video_path, output_folder)
    
    # Verify output
    assert os.path.exists(output_folder)
    
    # Check CSV content
    with open(os.path.join(output_folder, "frame_timestamps.csv"), 'r') as f:
        lines = f.readlines()
        assert len(lines) == 4 # Header + 3 frames
        
        first_row = lines[1].strip().split(',')
        # Timestamp should be relative to 0
        assert float(first_row[1]) >= 0.0
        assert float(first_row[1]) < 100.0 # Should be small
