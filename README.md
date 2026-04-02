# Kiosk Player App

Ứng dụng Flutter desktop để chạy nội dung kiosk trên Windows, Linux và Raspberry Pi.

## Chức năng hiện có

- Chạy playlist từ URL JSON
- Phát được: image, video, audio, PDF, web, slide
- Toàn màn hình / always on top
- Màn hình cấu hình thiết bị
- Tự tải lại playlist theo chu kỳ
- Danh sách phát xem trước trước khi chạy kiosk

## Cấu trúc JSON playlist

Bạn có thể trả về một trong hai dạng dưới đây.

### Dạng 1

```json
{
  "name": "Playlist trung tâm",
  "playlist": [
    {
      "id": "img-1",
      "type": "image",
      "title": "Banner chào mừng",
      "subtitle": "Sảnh chính",
      "url": "https://example.com/banner.jpg",
      "durationSeconds": 12
    },
    {
      "id": "video-1",
      "type": "video",
      "title": "Video giới thiệu",
      "url": "https://example.com/intro.mp4"
    },
    {
      "id": "pdf-1",
      "type": "pdf",
      "title": "Lịch công tác",
      "url": "https://example.com/lich.pdf",
      "durationSeconds": 18
    },
    {
      "id": "web-1",
      "type": "web",
      "title": "Dashboard web",
      "url": "https://example.com/dashboard",
      "durationSeconds": 20
    }
  ]
}
```

### Dạng 2

```json
[
  {
    "id": "1",
    "type": "image",
    "title": "Ảnh 1",
    "url": "https://example.com/a.jpg",
    "durationSeconds": 10
  }
]
```

## Chạy ứng dụng

```bash
flutter pub get
flutter run -d windows
# hoặc
flutter run -d linux
```

## Build phát hành

### Windows

```bash
flutter build windows --release
```

### Linux / Raspberry Pi

```bash
flutter build linux --release
```

## Gợi ý triển khai thực tế

- Mỗi thiết bị có một URL playlist riêng, ví dụ:
  - `https://server.local/kiosk/room-a.json`
  - `https://server.local/kiosk/door-a.json`
- Có thể sinh JSON từ backend `kiosk_controller`
- Khi đã ổn định mới chuyển từ URL Internet sang server nội bộ LAN

## Hướng mở rộng tiếp theo

- Poll lệnh điều khiển realtime từ backend
- Đồng bộ trạng thái `playing / online / current_item`
- Tải trước nội dung về cache offline
- Watchdog tự khởi động lại player khi treo
- Chế độ nhiều zone / nhiều màn hình
# player_app
