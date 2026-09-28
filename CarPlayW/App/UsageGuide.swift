import Foundation

enum UsageGuide {
    static let projectURL = URL(string: "https://lxjc.com/index.php/archives/416/")!
    static let writeSuccessMessage = "亮暗壁纸已写入。可先到「缓存」查看实际文件确认效果，推荐重启手机后重新连接 CarPlay。系统可能重新生成缓存，如未生效请返回应用刷新检查。"
    static let steps = [
        "连接 CarPlay，在车机「设置 → 壁纸」选择系统壁纸，生成缓存。",
        "断开 CarPlay，打开本应用，点击右上角刷新。",
        "选择系列，在「缓存」查看原图尺寸；选择一张图片，同时写入亮暗壁纸。",
        "写入成功后推荐重启手机，再重新连接 CarPlay 查看效果。"
    ]
}
