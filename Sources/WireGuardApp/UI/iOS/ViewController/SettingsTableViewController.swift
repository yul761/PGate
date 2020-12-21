// SPDX-License-Identifier: MIT
// Copyright © 2018-2019 pGate LLC. All Rights Reserved.

import UIKit
import os.log

class SettingsTableViewController: UITableViewController {

    enum SettingsFields {
        case languageChange
        case iosAppVersion
        case goBackendVersion
        case exportZipArchive
        case viewLog
//        case donateLink

        var localizedUIString: String {
            switch self {
            case .languageChange: return tr("settingsSectionTitleLanguageNameEnglish")
            case .iosAppVersion: return tr("settingsVersionKeyWireGuardForIOS")
            case .goBackendVersion: return tr("settingsVersionKeyWireGuardGoBackend")
            case .exportZipArchive: return tr("settingsExportZipButtonTitle")
            case .viewLog: return tr("settingsViewLogButtonTitle")
//            case .donateLink: return tr("donateLink")
            }
        }
    }

    let settingsFieldsBySection: [[SettingsFields]] = [
        [.languageChange],
        [.iosAppVersion, .goBackendVersion],//, .donateLink],
        [.exportZipArchive],
        [.viewLog]
    ]

    let tunnelsManager: TunnelsManager?
    var wireguardCaptionedImage: (view: UIView, size: CGSize)?

    init(tunnelsManager: TunnelsManager?) {
        self.tunnelsManager = tunnelsManager
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = tr("settingsViewTitle")
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))

        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension
        tableView.allowsSelection = false

        tableView.register(KeyValueCell.self)
        tableView.register(ButtonCell.self)
        tableView.register(LanguageValueCell.self)

        tableView.tableFooterView = UIImageView(image: UIImage(named: "wireguard.pdf"))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let logo = tableView.tableFooterView else { return }

        let bottomPadding = max(tableView.layoutMargins.bottom, 10)
        let fullHeight = max(tableView.contentSize.height, tableView.bounds.size.height - tableView.layoutMargins.top - bottomPadding)

        let imageAspectRatio = logo.intrinsicContentSize.width / logo.intrinsicContentSize.height

        var height = tableView.estimatedRowHeight * 1.5
        var width = height * imageAspectRatio
        let maxWidth = view.bounds.size.width - max(tableView.layoutMargins.left + tableView.layoutMargins.right, 20)
        if width > maxWidth {
            width = maxWidth
            height = width / imageAspectRatio
        }

        let needsReload = height != logo.frame.height

        logo.frame = CGRect(x: (view.bounds.size.width - width) / 2, y: fullHeight - height, width: width, height: height)

        if needsReload {
            tableView.tableFooterView = logo
        }
    }

    @objc func doneTapped() {
        dismiss(animated: true, completion: nil)
    }

    func exportConfigurationsAsZipFile(sourceView: UIView) {
        PrivateDataConfirmation.confirmAccess(to: tr("iosExportPrivateData")) { [weak self] in
            guard let self = self else { return }
            guard let tunnelsManager = self.tunnelsManager else { return }
            guard let destinationDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

            let destinationURL = destinationDir.appendingPathComponent("PGate-export.zip")
            _ = FileManager.deleteFile(at: destinationURL)

            let count = tunnelsManager.numberOfTunnels()
            let tunnelConfigurations = (0 ..< count).compactMap { tunnelsManager.tunnel(at: $0).tunnelConfiguration }
            ZipExporter.exportConfigFiles(tunnelConfigurations: tunnelConfigurations, to: destinationURL) { [weak self] error in
                if let error = error {
                    ErrorPresenter.showErrorAlert(error: error, from: self)
                    return
                }

                let fileExportVC = UIDocumentPickerViewController(url: destinationURL, in: .exportToService)
                self?.present(fileExportVC, animated: true, completion: nil)
            }
        }
    }

    func presentLogView() {
        let logVC = LogViewController()
        navigationController?.pushViewController(logVC, animated: true)

    }
}

extension SettingsTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return settingsFieldsBySection.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsFieldsBySection[section].count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return tr("settingsSectionTitleLanguage")
        case 1:
            return tr("settingsSectionTitleAbout")
        case 2:
            return tr("settingsSectionTitleExportConfigurations")
        case 3:
            return tr("settingsSectionTitleTunnelLog")
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let field = settingsFieldsBySection[indexPath.section][indexPath.row]
        if field == .iosAppVersion || field == .goBackendVersion {
            let cell: KeyValueCell = tableView.dequeueReusableCell(for: indexPath)
            cell.copyableGesture = false
            cell.key = field.localizedUIString
            if field == .iosAppVersion {
                var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown version"
                if let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    appVersion += " (\(appBuild))"
                }
                cell.value = appVersion
            } else if field == .goBackendVersion {
                cell.value = WIREGUARD_GO_VERSION
            }
            return cell
        } else if field == .exportZipArchive {
            let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)
            cell.buttonText = field.localizedUIString
            cell.onTapped = { [weak self] in
                self?.exportConfigurationsAsZipFile(sourceView: cell.button)
            }
            return cell
        } else if field == .viewLog {
            let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)
            cell.buttonText = field.localizedUIString
            cell.onTapped = { [weak self] in
                self?.presentLogView()
            }
            return cell
        } /*else if field == .donateLink {
            let cell: ButtonCell = tableView.dequeueReusableCell(for: indexPath)
            cell.buttonText = field.localizedUIString
            cell.onTapped = {
                if let url = URL(string: "https://www.wireguard.com/donations/"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:])
                }
            }
            return cell
         }*/ else if field == .languageChange {
            let cell: LanguageValueCell = tableView.dequeueReusableCell(for: indexPath)
            cell.copyableGesture = false
            cell.onTapped = { [weak self] (_ switchh: UISwitch) -> Void in
                print("Changed language")
//                self?.tableView.reloadData()//.viewDidLoad()
//                self?.exportConfigurationsAsZipFile(sourceView: cell.button)

                var langPreix = "en"
                if switchh == cell.languageSwitch {
                    if switchh.isOn {
                        langPreix = "en"
                    } else {
                        langPreix = "zh-Hans"//"ja"//"ja_JP"
                    }
                } else {
                    if switchh.isOn {
                        langPreix = "zh-Hans"
                    } else {
                        langPreix = "en"
                    }
                }


                let alt = UIAlertController(title: tr("Alert"), message: tr("applyLanguage"), preferredStyle: .alert)
                let yes = UIAlertAction(title: tr("Yes"), style: .default) { [weak self] (_) in
                    print("Language prefix: \(langPreix)")
                    UserDefaults.standard.set([langPreix], forKey: "AppleLanguages")
                    UserDefaults.standard.synchronize()

                    if langPreix == "en" {
                        cell.languageSwitch.setOn(true, animated: true)
                        cell.secondLanguageSwitch.setOn(false, animated: true)
                    } else {
                        cell.languageSwitch.setOn(false, animated: true)
                        cell.secondLanguageSwitch.setOn(true, animated: true)
                    }

                    let alt = UIAlertController(title: tr("Alert"), message: tr("restartApp"), preferredStyle: .alert)
                    let ok = UIAlertAction(title: tr("Ok"), style: .default, handler: { (action:UIAlertAction!) -> Void in
                        //after user press ok, the following code will be execute
                        UIControl().sendAction(Selector("suspend"), to: UIApplication.shared, for: nil)
                        exit(0)
                     })
                    alt.addAction(ok)
                    self?.present(alt, animated: true, completion: nil)
                }
                let no = UIAlertAction(title: tr("No"), style: .default) { (_) in
//                    cell.languageSwitch.setOn(!isOn, animated: false)
                    if langPreix == "en" {
                        cell.languageSwitch.setOn(false, animated: true)
                        cell.secondLanguageSwitch.setOn(true, animated: true)
                    } else {
                        cell.languageSwitch.setOn(true, animated: true)
                        cell.secondLanguageSwitch.setOn(false, animated: true)
                    }
                }
                alt.addAction(yes)
                alt.addAction(no)
                self?.present(alt, animated: true, completion: nil)

//                if let languageDirectoryPath = Bundle.main.path(forResource: langPreix, ofType: "lproj") {
//                    bundle = Bundle.init(path: languageDirectoryPath) ?? Bundle()
//                } else {
//                    resetLocalization()
//                }
            }
            cell.key = tr("settingsSectionTitleLanguageNameEnglish")//field.localizedUIString
            cell.secondKey = tr("settingsSectionTitleLanguageNameChinese")//field.localizedUIString

//            if field == .languageChange {
//                var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown version"
//                if let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
//                    appVersion += " (\(appBuild))"
//                }
//                cell.value = appVersion
//            }
            return cell
        }
        fatalError()
    }
}
