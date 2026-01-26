import os, cv2

SCRIPTS_PATH = os.path.dirname(os.path.abspath(__file__))

CLIPS = [
    # "Idle.mp4",
    "Walk.mp4",
    "Trot.mp4",
    "Gallop.mp4",
    "Jump.mp4",
]

r = 2
IN_LINE_SIZE = (int(1920 / r * len(CLIPS)), int(1080 / r))


out_clip = cv2.VideoWriter(
    os.path.join(SCRIPTS_PATH, "All_in_line.mp4"),
    cv2.VideoWriter_fourcc(*"mp4v"),
    24,
    IN_LINE_SIZE,
)

caps = [cv2.VideoCapture(os.path.join(SCRIPTS_PATH, clip)) for clip in CLIPS]

try:
    frames_exist = True
    while frames_exist:
        frames = []
        for cap in caps:
            ret, frame = cap.read()
            if not ret:
                frames_exist = False
                break
            frame = cv2.resize(frame, (int(1920/r), int(1080/r)))
            frames.append(frame)
        if not frames_exist or len(frames) != len(CLIPS):
            break
        combined = cv2.hconcat(frames)
        out_clip.write(combined)
except Exception as e:
    for cap in caps:
        cap.release()
    exit(1)

for cap in caps:
    cap.release()
out_clip.release()