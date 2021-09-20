//
//  ViewController.swift
//  StandUp
//
//  Created by Peter on 31/10/19.
//  Copyright © 2019 Blockchain Commons, LLC
//

import Cocoa

class ViewController: NSViewController, NSWindowDelegate {
    
    @IBOutlet weak private var startTorOutlet: NSButton!
    @IBOutlet weak private var networkLabel: NSTextField!
    @IBOutlet weak private var mainnetIncomingImage: NSImageView!
    @IBOutlet weak private var bitcoinCoreWindow: NSView!
    @IBOutlet weak private var torWindow: NSView!
    @IBOutlet weak private var torAuthWindow: NSView!
    @IBOutlet weak private var startMainnetOutlet: NSButton!
    @IBOutlet weak private var bitcoinCoreHeaderOutlet: NSTextField!
    @IBOutlet weak private var bitcoinCoreVersionOutlet: NSTextField!
    @IBOutlet weak private var torVersionOutlet: NSTextField!
    @IBOutlet weak private var torAuthLockImage: NSImageView!
    @IBOutlet weak private var torAuthRemoveOutlet: NSButton!
    @IBOutlet weak private var taskDescription: NSTextField!
    @IBOutlet weak private var spinner: NSProgressIndicator!
    @IBOutlet weak private var verifyOutlet: NSButton!
    @IBOutlet weak private var updateOutlet: NSButton!
    @IBOutlet weak private var icon: NSImageView!
    @IBOutlet weak private var torRunningImage: NSImageView!
    @IBOutlet weak private var mainnetSyncedLabel: NSTextField!
    @IBOutlet weak private var mainnetIncomingPeersLabel: NSTextField!
    @IBOutlet weak private var mainnetOutgoingPeersLabel: NSTextField!
    @IBOutlet weak private var bitcoinIsOnHeaderImage: NSImageView!
    @IBOutlet weak private var networkButton: NSPopUpButton!
    
    weak var mgr = TorClient.sharedInstance
    //var installingLightning = Bool()
    var timer: Timer?
    //var httpPass = ""
    var chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
    var rpcpassword = ""
    var rpcuser = ""
    var torHostname = ""
    var mainHostname = ""
    var testHostname = ""
    var regHostname = ""
    //var lightningP2pHostname = ""
    //var lightningRpcHostname = ""
    var network = ""
    var rpcport = ""
    var newestVersion = ""
    var newestBinaryName = ""
    var newestPrefix = ""
    var strapping = false
    var standingUp = false
    var bitcoinInstalled = false
    var torIsOn = false
    var bitcoinRunning = false
    var upgrading = false
    var isLoading = false
    var torConfigured = false
    var bitcoinConfigured = false
    var ignoreExistingBitcoin = false
    var regTestOn = false
    //var lightningIsRunning = false
    //var lightningInstalled = false
    var env = [String:String]()
    let d = Defaults()
    var infoMessage = ""
    var headerText = ""
    var installingTor = false
    var updatingTor = false
    var installingXcode = false
    var currentVersion = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        isLoading = true
        NotificationCenter.default.addObserver(self, selector: #selector(refreshNow), name: .refresh, object: nil)
        
        d.setDefaults { [weak self] in
            guard let self = self else { return }
            
            self.setEnv()
            self.setScene()
        }
    }

    override func viewWillAppear() {
        self.view.window?.delegate = self
        self.view.window?.minSize = NSSize(width: 544, height: 377)
    }

    override func viewDidAppear() {
        var frame = self.view.window!.frame
        let initialSize = NSSize(width: 544, height: 377)
        frame.size = initialSize
        self.view.window?.setFrame(frame, display: true)
        
        if isLoading {
            if mgr?.state != .started && mgr?.state != .connected  {
                mgr?.start(delegate: self)
            }
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Quit Tor and Bitcoin Core?"
        alert.informativeText = "Closing this window does not automatically quit Tor or Bitcoin Core."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Leave Running")
        alert.alertStyle = .warning
        let modalResponse = alert.runModal()
        if (modalResponse == NSApplication.ModalResponse.alertFirstButtonReturn) {
            self.runScript(script: .stopBitcoin)
            self.mgr?.resign()
        }
        return true
    }
    
    @IBAction func showSettingsAction(_ sender: Any) {
        var myWindow: NSWindow? = nil
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let settings = storyboard.instantiateController(withIdentifier: "Settings") as! Settings
        myWindow = NSWindow(contentViewController: settings)
        NSApp.activate(ignoringOtherApps: true)
        myWindow?.makeKeyAndOrderFront(self)
        let vc = NSWindowController(window: myWindow)
        vc.showWindow(self)
    }
    
    @IBAction func showQuickConnectAction(_ sender: Any) {
        if torIsOn {
            var myWindow: NSWindow? = nil
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            let quickconnect = storyboard.instantiateController(withIdentifier: "QuickConnect") as! QRDisplayer
            myWindow = NSWindow(contentViewController: quickconnect)
            NSApp.activate(ignoringOtherApps: true)
            myWindow?.makeKeyAndOrderFront(self)
            let vc = NSWindowController(window: myWindow)
            vc.showWindow(self)
        } else {
            simpleAlert(message: "Tor not installed...", info: "In order to connect to your node remotely you need to install Tor first.", buttonLabel: "OK")
        }
    }    

    @objc func refreshNow() {
        //refresh()
        checkForGordian()
    }

    private func checkForBitcoinUpdate() {
        d.setDefaults { [unowned vc = self] in
            vc.getLatestVersion { [unowned vc = self] (success, errorMessage) in
                if success {
                    vc.setEnv()
                    if self.currentVersion.contains(self.d.existingVersion()) {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.updateOutlet.isEnabled = false
                            vc.updateOutlet.title = "Update"
                        }
                    } else {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.updateOutlet.title = "Update"
                            vc.updateOutlet.isEnabled = true
                            
                            actionAlert(message: "A newer version of Bitcoin Core has been released. Upgrade to Bitcoin Core \(vc.newestVersion)?", info: "") { (response) in
                                if response {
                                    DispatchQueue.main.async { [unowned vc = self] in
                                        vc.upgrading = true
                                        vc.timer?.invalidate()
                                        vc.performSegue(withIdentifier: "goInstall", sender: vc)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    simpleAlert(message: "Network request error", info: errorMessage ?? "We had an issue getting a response from the Bitcoin Core repo on GitHub, we do this to check for new releases, you can ignore this error but we thought you should know something is up, please check your internet connection.", buttonLabel: "OK")
                    vc.setEnv()
                }
            }
        }
    }

    //MARK: User Action
    
    @IBAction func userSelectedMainnet(_ sender: Any) {
        UserDefaults.standard.setValue("main", forKey: "chain")
        chain = "main"
        setEnv()
        refreshAction()
    }
    
    @IBAction func userSelectedTestnet(_ sender: Any) {
        UserDefaults.standard.setValue("test", forKey: "chain")
        chain = "test"
        setEnv()
        refreshAction()
    }
    
    @IBAction func userSelectedRegtest(_ sender: Any) {
        UserDefaults.standard.setValue("regtest", forKey: "chain")
        chain = "regtest"
        setEnv()
        refreshAction()
    }
    
    @IBAction func userSelectedSignet(_ sender: Any) {
        UserDefaults.standard.setValue("signet", forKey: "chain")
        chain = "signet"
        setEnv()
        refreshAction()
    }
    
    @IBAction func showLightningQuickConnect(_ sender: Any) {
//        DispatchQueue.main.async { [unowned vc = self] in
//            vc.rpcport = "1312"
//            vc.network = "lightning"
//            vc.torHostname = vc.lightningRpcHostname
//            vc.performSegue(withIdentifier: "showPairingCode", sender: vc)
//        }
    }

    @IBAction func installLightningAction(_ sender: Any) {
//        if !lightningInstalled {
//            actionAlert(message: "This is reckless!", info: "This will install c-lightning from source, a lot of things can go wrong when installing from source but generally it should work just fine. Click yes to install.") { [weak self]  response in
//                guard let self = self else { return }
//                if response {
//                    DispatchQueue.main.async { [weak self] in
//                        self?.installLightningOutlet.isEnabled = false
//                    }
//                    self.installingLightning = true
//                    self.standingUp = false
//                    self.upgrading = false
//                    self.strapping = false
//                    self.runScript(script: .getLightningHostnames)
//                }
//            }
//        } else {
//            if lightningIsRunning {
//                DispatchQueue.main.async { [weak self] in
//                    self?.startSpinner(description: "stopping lightning...")
//                }
//                self.runScript(script: .stopLightning)
//
//            } else {
//                DispatchQueue.main.async { [weak self] in
//                    self?.startSpinner(description: "checking Bitcoin Core sync status...")
//                }
//
//                MakeRpcCall.shared.command(method: "getblockchaininfo", port: "8332", user: rpcuser, password: rpcpassword) { [weak self] result in
//                    guard let self = self else { return }
//
//                    guard let result = result as? NSDictionary, let verificationprogress = result["verificationprogress"] as? Double else {
//                        self.hideSpinner()
//                        self.showAlertMessage(message: "Ooops", info: "We did not get a valid response from Bitcoin Core, ensure mainnet is running and fully synced then try again")
//                        return
//                    }
//
//                    guard verificationprogress > 0.9999 else {
//                        self.hideSpinner()
//                        self.showAlertMessage(message: "Bitcoin Core not fully synced", info: "In order to use lightning your node needs to be fully synced")
//                        return
//                    }
//
//                    DispatchQueue.main.async { [weak self] in
//                        guard let self = self else { return }
//
//                        self.taskDescription.stringValue = "starting lightning..."
//                        self.runScript(script: .startLightning)
//                    }
//                }
//            }
//        }
    }

    @IBAction func refreshAction(_ sender: Any) {
        refreshAction()
    }
    
    private func addSpinnerDesc(_ description: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.taskDescription.stringValue = description
            self.spinner.startAnimation(self)
            self.spinner.alphaValue = 1
            self.taskDescription.alphaValue = 1
        }
    }
    
    private func refreshAction() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.taskDescription.stringValue = "checking system..."
            self.spinner.startAnimation(self)
            self.spinner.alphaValue = 1
            self.taskDescription.alphaValue = 1
        }
        
        checkForGordian()
    }

    @IBAction func removeAuthAction(_ sender: Any) {
        let chain = UserDefaults.standard.string(forKey: "chain") ?? "main"
        
        actionAlert(message: "Remove \(chain) network authentication keys?", info: "Removing your authentication keys means anyone who gets your quick connect QR will be able to access your \(chain) network Bitcoin Core wallets. Are you sure you want to remove all authentication keys?") { response in
            if response {
                let path = "\(TorClient.sharedInstance.torPath())/host/bitcoin/\(chain)/authorized_clients/"
                
                do {
                    let filePaths = try FileManager.default.contentsOfDirectory(atPath: path)
                    for (i, filePath) in filePaths.enumerated() {
                        try FileManager.default.removeItem(atPath: path + filePath)
                        
                        if i + 1 == filePaths.count {
                            simpleAlert(message: "Success", info: "Authorized clients files removed, your \(chain) network Bitcoin Core rpc hidden services are no longer authenticated!", buttonLabel: "OK")
                        }
                    }
                } catch {
                    simpleAlert(message: "There was an issue deleting your auth keys...", info: "\(error.localizedDescription)\n\nPlease let us know about this bug.", buttonLabel: "OK")
                }
            }
        }
    }

    private func addAuth() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "addAuth", sender: vc)
        }
    }

    @IBAction func addAuthAction(_ sender: Any) {
        addAuth()
    }

    @IBAction func startMainnetAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.startMainnetOutlet.isEnabled = false
        }
        
        if !bitcoinRunning {
            addSpinnerDesc("starting \(chain)...")
            runScript(script: .startBitcoin)
        } else {
            addSpinnerDesc("stopping \(chain)...")
            runScript(script: .stopBitcoin)
        }
    }

    @IBAction func bitcoinWindowHelp(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.headerText = "Bitcoin Core"
            self.infoMessage = "Gordian Server creates a ~./gordian directory where it installs Bitcoin Core. Gordian Server works with the default Bitcoin directory at /Users/\(NSUserName())/Library/Application Support/Bitcoin. Specify a custom blocksdir for storing the blockchain via File > Settings (or the settings button). Run multiple networks (main, test, regtest, signet) simultaneously, useful for development and testing purposes. Click the QR button to remotely connect to your node. Click Go To for more tools. Bitcoin is run in the background, even if you quit Gordian Server Bitcoin Core will continue running unless you stop it."
            self.performSegue(withIdentifier: "segueToHelp", sender: self)
        }
    }

    @IBAction func torWindowHelp(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.headerText = "Tor"
            self.infoMessage = "Gordian Server integrates Tor to make connecting to your node easy, secure and private. You must leave Gordian Server running in order to connect to your node remotely as quitting the app will also quit Tor. If you run Tor elsewhere on your computer Gordian Server will not interfere with it. You may start/stop Tor and add/remove Tor authentication keys with Gordian Server. Click the Go To menu item to see additonal Tor related tools."
            self.performSegue(withIdentifier: "segueToHelp", sender: self)
        }
    }

    @IBAction func updateBitcoin(_ sender: Any) {
        if !bitcoinInstalled {
            installNow()
        } else {
            DispatchQueue.main.async {
                FetchLatestRelease.get { (dict, err) in
                    if err != nil {
                        simpleAlert(message: "Error", info: "Error fetching latest release: \(err ?? "unknown error")", buttonLabel: "OK")
                    } else {
                        let version = dict!["version"] as! String
                        actionAlert(message: "Upgrade to Bitcoin Core \(version)?", info: "") { (response) in
                            if response {
                                DispatchQueue.main.async { [unowned vc = self] in
                                    vc.upgrading = true
                                    vc.timer?.invalidate()
                                    vc.performSegue(withIdentifier: "goInstall", sender: vc)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    //MARK: User Action Installers, Starters and Configurators

    @IBAction func verifyAction(_ sender: Any) {
        runScript(script: .verifyBitcoin)
    }

    private func installNow() {
        startSpinner(description: "Fetching latest Bitcoin Core version...")
        FetchLatestRelease.get { [unowned vc = self] (dict, error) in

            if error != nil {
                vc.hideSpinner()
                simpleAlert(message: "Error", info: error ?? "We had an error fetching the latest version of Bitcoin Core, please check your internet connection and try again", buttonLabel: "OK")

            } else {
                vc.hideSpinner()
                let version = dict!["version"] as! String

                // Installing from scratch, however user may have gone into settings and changed some things so we need to check for that.
                func standup() {
                    let pruned = vc.d.prune()
                    let txindex = vc.d.txindex()
                    let directory = vc.d.dataDir()
                    let pruneInGb = Double(pruned) / 954.0
                    let rounded = Double(round(100 * pruneInGb) / 100)

                    self.infoMessage = """
                    Gordian Server will install and configure a pruned (\(rounded)gb) Bitcoin Core node.

                    You can always edit settings via File > Settings.

                    If your node is already running you will need to restart it for the new settings to take effect.

                    Gordian Server will create the following directory: /Users/\(NSUserName())/.gordian

                    It will create or add missing rpc credentials to the bitcoin.conf in \(directory).
                    """

                    if pruned == 0 || pruned == 1 {
                        self.infoMessage = """
                        GordianServer will install and configure Bitcoin Core node.

                        You have set pruning to \(pruned), you can always edit the pruning amount in settings.

                        You can always edit settings via File > Settings.

                        GordianServer will create the following directory: /Users/\(NSUserName())/.gordian

                        It will create or add missing rpc credentials to the bitcoin.conf in \(directory).
                        """
                    }

                    if txindex == 1 {
                        self.infoMessage = """
                        Gordian Server will install and configure a fully indexed Bitcoin Core node.

                        You can always edit settings via File > Settings.

                        Gordian Server will create the following directory: /Users/\(NSUserName())/.gordian

                        It will create or add missing rpc credentials to the bitcoin.conf in \(directory).
                        """
                    }
                    
                    self.headerText = "Install Bitcoin Core v\(version)?"
                    self.ignoreExistingBitcoin = false
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.performSegue(withIdentifier: "segueToInstallPrompt", sender: self)
                    }
                }

                // Bitcoind and possibly tor are already installed
                if vc.bitcoinInstalled {

                    self.headerText = "Install Bitcoin Core v\(version)?"

                    self.infoMessage = """
                    Selecting yes will tell Gordian Server to download, verify and install a fresh Bitcoin Core v\(version) installation in ~/.gordian/BitcoinCore, Gordian Server will not overwrite your existing node.

                    Your existing bitcoin.conf file will be checked for rpc username and password, if none exist Gordian Server will create them for you, all other bitcoin.conf settings will remain in place.
                    """
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.ignoreExistingBitcoin = true
                        self.performSegue(withIdentifier: "segueToInstallPrompt", sender: self)
                    }
                } else {
                    standup()
                }
            }
        }
    }

    @IBAction func standUp(_ sender: Any) {
        installNow()
    }
    
    @IBAction func startTorAction(_ sender: Any) {
        if !torIsOn {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.startSpinner(description: "starting tor...")
                vc.startTorOutlet.isEnabled = false
                vc.mgr?.start(delegate: self)
            }
        } else {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.startTorOutlet.isEnabled = false
                vc.mgr?.resign()
                vc.updateTorStatus(isOn: false)
            }
        }
    }
    
    // MARK: Script Methods

    func checkForXcodeSelect() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.taskDescription.stringValue = "checking for xcode select..."
            vc.runScript(script: .checkXcodeSelect)
        }
    }

    func isBitcoinOn() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.taskDescription.stringValue = "checking if bitcoin core is running..."
        }
        
        runScript(script: .isBitcoinOn)
    }

    func checkBitcoindVersion() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.taskDescription.stringValue = "checking if bitcoin core is installed..."
            vc.runScript(script: .checkForBitcoin)
        }
    }

    func checkBitcoinConfForRPCCredentials() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.taskDescription.stringValue = "getting rpc credentials..."
            
            let path = URL(fileURLWithPath: "/Users/\(NSUserName())/Library/Application Support/Bitcoin/bitcoin.conf")
            
            guard let conf = try? String(contentsOf: path, encoding: .utf8) else {
                print("can not get bitcoin.conf")
                return
            }
            
            self.checkForRPCCredentials(response: conf)
        }
    }

    func checkForGordian() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.taskDescription.stringValue = "checking for ~/.gordian directory..."
            vc.runScript(script: .checkStandUp)
        }
    }
    
    private func isLightningRunning() {
        DispatchQueue.main.async { [weak self] in
            self?.taskDescription.stringValue = "checking if lightning is running..."
            self?.runScript(script: .isLightningRunning)
        }
    }
    
    private func getLightningHttpPass() {
        DispatchQueue.main.async { [weak self] in
            self?.runScript(script: .getLightningRpcCreds)
        }
    }
    
    private func getLightningRpcHost() {
        DispatchQueue.main.async { [weak self] in
            self?.runScript(script: .getLightningHostnames)
        }
    }

    private func runScript(script: SCRIPT) {
        #if DEBUG
        print("script: \(script.rawValue)")
        #endif
        
        let taskQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
        taskQueue.async { [weak self] in
            let resource = script.rawValue
            guard let path = Bundle.main.path(forResource: resource, ofType: "command") else { return }
            let stdOut = Pipe()
            let stdErr = Pipe()
            let task = Process()
            task.launchPath = path
            task.environment = self?.env
            task.standardOutput = stdOut
            task.standardError = stdErr
            task.launch()
            task.waitUntilExit()
            let data = stdOut.fileHandleForReading.readDataToEndOfFile()
            let errData = stdErr.fileHandleForReading.readDataToEndOfFile()
            var result = ""
            
            if let output = String(data: data, encoding: .utf8) {
                #if DEBUG
                print("output: \(output)")
                #endif
                result += output
            }
            
            if let errorOutput = String(data: errData, encoding: .utf8) {
                #if DEBUG
                print("error: \(errorOutput)")
                if errorOutput != "" && !errorOutput.contains("not connect to the server") && !errorOutput.contains("block") && !errorOutput.contains("Loading P2P addresses")  {
                    simpleAlert(message: "Error", info: errorOutput, buttonLabel: "OK")
                }
                
                #endif
                result += errorOutput
            }
            
            self?.parseScriptResult(script: script, result: result)
        }
    }

    //MARK: Script Result Filters

    func parseScriptResult(script: SCRIPT, result: String) {
        switch script {
        case .checkStandUp:
            checkStandUpParser(result: result)
            
        case .stopBitcoin:
            stopBitcoinParse(result: result)
            
        case .startBitcoin:
            startBitcoinParse(result: result)

        case .isBitcoinOn:
            parseIsBitcoinOn(result: result)

        case .checkForBitcoin:
            parseBitcoindResponse(result: result)

        case .verifyBitcoin:
            parseVerifyResult(result: result)

        case .checkXcodeSelect:
            parseXcodeSelectResult(result: result)
            
//        case .getLightningHostnames:
//            parseLightningHostnames(result: result)
//
//        case .isLightningInstalled:
//            parseLightningInstalledResponse(result: result)
//
//        case .isLightningRunning:
//            parseIsLightningRunningResponse(result: result)
//
//        case .startLightning:
//            startLightningParse(result: result)
//
//        case .stopLightning:
//            stopLightningParse(result: result)
//
//        case .getLightningRpcCreds:
//            parseLightningConfig(result: result)

        default: break
        }
    }
    
//    private func parseTorUpdateAvailable(result: String) {
//        if result.contains("Tor") || result.contains("tor") {
//            DispatchQueue.main.async { [weak self] in
//                guard let self = self else { return }
//
//                self.updateTorOutlet.isEnabled = true
//            }
//        } else {
//            DispatchQueue.main.async { [weak self] in
//                guard let self = self else { return }
//
//                self.updateTorOutlet.isEnabled = false
//            }
//        }
//    }
    
//    private func parseLightningConfig(result: String) {
//        let arr = result.split(separator: "\n")
//        for item in arr {
//            if item.contains("http-pass") {
//                let arr1 = item.split(separator: "=")
//                httpPass = "\(arr1[1])"
//                getLightningRpcHost()
//            }
//        }
//    }
//
//    private func parseLightningHostnames(result: String) {
//        let arr = result.split(separator: "\n")
//        if arr.count > 0 {
//            DispatchQueue.main.async { [weak self] in
//                self?.lightningP2pHostname = "\(arr[0])"
//                self?.lightningRpcHostname = "\(arr[1])"
//                if self!.installingLightning {
//                    self?.performSegue(withIdentifier: "goInstall", sender: self)
//                } else {
//                    DispatchQueue.main.async { [weak self] in
//                        self?.lightningQuickConnectOutlet.isEnabled = true
//                    }
//                }
//            }
//        }
//    }
    
//    private func stopLightningParse(result: String) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [unowned vc = self] in
//            vc.runScript(script: .isLightningRunning)
//            vc.hideSpinner()
//        }
//    }
//
//    private func startLightningParse(result: String) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [unowned vc = self] in
//            vc.runScript(script: .isLightningRunning)
//            vc.hideSpinner()
//        }
//    }
    
//    private func parseIsLightningRunningResponse(result: String) {
//        if result.contains("No such file or directory") {
//            DispatchQueue.main.async { [weak self] in
//                self?.lightningStatusIcon.image = NSImage(imageLiteralResourceName: "NSStatusUnavailable")
//                self?.installLightningOutlet.title = "Start"
//                self?.lightningIsRunning = false
//                self?.lightningQuickConnectOutlet.isEnabled = false
//            }
//
//        } else if let dict = convertStringToDictionary(json: result) {
//            let version = dict["version"] as? String ?? ""
//            DispatchQueue.main.async { [weak self] in
//                self?.lightningVersionLabel.stringValue = version
//                self?.lightningStatusIcon.image = NSImage(imageLiteralResourceName: "NSStatusAvailable")
//                self?.installLightningOutlet.title = "Stop"
//                self?.lightningIsRunning = true
//                self?.getLightningHttpPass()
//            }
//        } else if result.contains("error") {
//            DispatchQueue.main.async { [weak self] in
//                self?.lightningStatusIcon.image = NSImage(imageLiteralResourceName: "NSStatusUnavailable")
//                self?.installLightningOutlet.title = "Start"
//                self?.lightningIsRunning = false
//                self?.lightningQuickConnectOutlet.isEnabled = false
//            }
//
//            showAlertMessage(message: "Error", info: result)
//
//        } else {
//            DispatchQueue.main.async { [weak self] in
//                self?.lightningStatusIcon.image = NSImage(imageLiteralResourceName: "NSStatusUnavailable")
//                self?.installLightningOutlet.title = "Start"
//                self?.lightningIsRunning = false
//                self?.lightningQuickConnectOutlet.isEnabled = false
//            }
//        }
//    }
    
//    private func parseLightningInstalledResponse(result: String) {
//        if result.contains("lightning installed") {
//            lightningInstalled = true
//            isLightningRunning()
//            if bitcoinInstalled && bitcoinRunning {
//                DispatchQueue.main.async { [weak self] in
//                    guard let self = self else { return }
//                    self.installLightningOutlet.isEnabled = true
//                    self.lightningWindow.alphaValue = 1
//                }
//            } else {
//                DispatchQueue.main.async { [weak self] in
//                    guard let self = self else { return }
//                    self.installLightningOutlet.isEnabled = false
//                    self.lightningWindow.alphaValue = 0.5
//                }
//            }
//        } else {
//            if bitcoinInstalled {
//                if bitcoinRunning && torIsOn {
//                    DispatchQueue.main.async { [weak self] in
//                        guard let self = self else { return }
//                        self.lightningWindow.alphaValue = 1
//                        self.installLightningOutlet.isEnabled = true
//                    }
//                } else {
//                    DispatchQueue.main.async { [weak self] in
//                        guard let self = self else { return }
//                        self.lightningWindow.alphaValue = 0.5
//                    }
//                }
//            }
//        }
//    }

//    private func parseOldHostResponse(result: String) {
//        if result.contains("Exists") {
//            actionAlert(message: "You have an outdated version of GordianServer", info: "You need to run through the installation script again to configure your new Tor hidden services and to be able to run more then one network at a time, GordianServer may not function properly otherwise.") { [unowned vc = self] response in
//                if response {
//                    vc.runScript(script: .removeOldHost)
//                    vc.installNow()
//                }
//            }
//        } else {
//            checkForAuth()
//        }
//    }

    private func parseAuthCheck(result: String) {
        if result.contains("Unauthenticated") && torConfigured && bitcoinConfigured {
            let ud = UserDefaults.standard
            if ud.object(forKey: "doNotAskForAuthAgain") == nil {
               //addAuth()
            }
        }
        //runScript(script: .isLightningInstalled)
    }

    private func bitcoinIsOff() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.bitcoinIsOnHeaderImage.image = NSImage(imageLiteralResourceName: "NSStatusUnavailable")
            self.bitcoinRunning = false
            self.startMainnetOutlet.title = "Start"
            self.startMainnetOutlet.isEnabled = true
            self.mainnetSyncedLabel.stringValue = ""
            self.mainnetIncomingPeersLabel.stringValue = ""
            self.mainnetOutgoingPeersLabel.stringValue = ""
        }
    }

    //MARK: Script Result Parsers
    
    private func stopBitcoinParse(result: String) {
        if result.contains("Bitcoin Core stopping") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                guard let self = self else { return }
                
                self.bitcoinIsOff()
            }
        } else {
            simpleAlert(message: "Error turning off mainnet", info: result, buttonLabel: "OK")
        }
    }

    private func startBitcoinParse(result: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [unowned vc = self] in
            vc.runScript(script: .isBitcoinOn)
        }
    }

    private func parseXcodeSelectResult(result: String) {
        hideSpinner()
        if result.contains("XCode select not installed") {
            self.headerText = "Xcode command line tools is not installed."
            self.infoMessage = "Gordian Server relies on Xcode command line tools for installing Bitcoin Core. It uses about 2.7gb of space and includes a bunch of useful tools to do Bitcoin and Lightning related tasks. Clicking \"Install\" will launch a terminal which starts the installation process for you, please follow any prompts and wait for the installation to complete."
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.performSegue(withIdentifier: "segueToInstallXcode", sender: self)
            }
        } else {
            installNow()
        }
    }

    func checkStandUpParser(result: String) {
        if result.contains("False") {
            checkForXcodeSelect()
        } else {
            checkBitcoindVersion()
        }
    }

    private func convertStringToDictionary(json: String) -> [String: AnyObject]? {
        if let data = json.data(using: .utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [.mutableLeaves, .allowFragments]) as? [String: AnyObject]
                return json
            } catch {
                return nil
            }
        }
        return nil
    }

    private func progress(dict: [String:AnyObject]) -> String {
        if let verificationprogress = dict["verificationprogress"] as? Double {
            return verificationprogress.bitcoinCoreSyncStatus
        } else {
            return ""
        }
    }

    private func parseIsBitcoinOn(result: String) {
        if result.contains("Could not connect to the server") {
            self.bitcoinIsOff()
            self.hideSpinner()
            
        } else if result.contains("chain") {
            self.bitcoinRunning = true
            
            if let dict = convertStringToDictionary(json: result) {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.mainnetSyncedLabel.stringValue = self.progress(dict: dict)
                    self.checkBitcoinConfForRPCCredentials()
                    self.bitcoinIsOnHeaderImage.image = NSImage(imageLiteralResourceName: "NSStatusAvailable")
                    self.startMainnetOutlet.title = "Stop"
                    self.startMainnetOutlet.isEnabled = true
                    self.setTimer()
                }
            } else {
                simpleAlert(message: "There was an issue...", info: "We had a problem parsing the response from Bitcoin Core. Please let us know about this.", buttonLabel: "OK")
            }
        } else {
            self.bitcoinRunning = true
            self.setTimer()
            simpleAlert(message: "Bitcoin Core Message", info: result + "\n\nGordian Server will auto refresh every 15 seconds. Please be patient while Bitcoin Core starts as it can take time. If the app feels stuck just tap the refresh button located under the logo. You can always monitor the log to see details of what is happening in real time by clicking \"Go To\" > \"Bitcoin Core Log\".", buttonLabel: "OK")
        }
        
        checkForBitcoinUpdate()
    }

    private func command(command: String, completion: @escaping ((Any?)) -> Void) {
        let rpc = MakeRpcCall.shared
        var port:String!
        switch chain {
        case "main":
            port = "8332"
        case "test":
            port = "18332"
        case "regtest":
            port = "18443"
        case "signet":
            port = "38332"
        default:
            break
        }
        rpc.command(method: command, port: port, user: UserDefaults.standard.string(forKey: "rpcuser")!, password: UserDefaults.standard.string(forKey: "rpcpassword")!) { (response, error) in
            if error == nil {
                completion((response))
            } else {
                if error!.contains("Loading block index") {
                    simpleAlert(message: "Loading blocks...", info: "Your node is just getting started, Gordian Server will auto refresh every 15 seconds. Please be patient while your node loads its blocks.", buttonLabel: "OK")
                } else if error!.contains("Verifying blocks") {
                    simpleAlert(message: "Verifying blocks...", info: "Your node is just getting started, Gordian Server will auto refresh every 15 seconds. Please be patient while your node verifies its blocks.", buttonLabel: "OK")
                } else if !error!.contains("Could not connect to the server") {
                    simpleAlert(message: "There was an issue.", info: error!, buttonLabel: "OK")
                }
            }
        }
    }

    func updateTorStatus(isOn: Bool) {
        torIsOn = isOn
        if isOn {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.torRunningImage.alphaValue = 1
                vc.torRunningImage.image = NSImage.init(imageLiteralResourceName: "NSStatusAvailable")
                vc.startTorOutlet.isEnabled = true
                vc.startTorOutlet.title = "Stop"
            }
        } else {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.torRunningImage.alphaValue = 1
                vc.torRunningImage.image = NSImage.init(imageLiteralResourceName: "NSStatusUnavailable")
                vc.startTorOutlet.isEnabled = true
                vc.startTorOutlet.title = "Start"
            }
        }
    }

    func checkForRPCCredentials(response: String) {
        let bitcoinConf = response.components(separatedBy: "\n")
        for item in bitcoinConf {
            if item.contains("rpcuser") {
                let arr = item.components(separatedBy: "rpcuser=")
                rpcuser = arr[1]
                UserDefaults.standard.setValue(rpcuser, forKey: "rpcuser")
            }
            if item.contains("rpcpassword") {
                let arr = item.components(separatedBy: "rpcpassword=")
                rpcpassword = arr[1]
                UserDefaults.standard.setValue(rpcpassword, forKey: "rpcpassword")
            }
            if item.contains("testnet=1") || item.contains("testnet=0") || item.contains("regtest=1") || item.contains("regtest=0") {
                simpleAlert(message: "Incompatible bitcoin.conf setting! Standup will not function properly.", info: "GordianServer allows you to run multiple networks simultaneously, we do this by specifying which chain we want to launch as a command line argument. Specifying a network in your bitcoin.conf is incompatible with this approach, please remove the line in your conf file which specifies a network to use GordianServer.", buttonLabel: "OK")
            }
        }
        if rpcpassword != "" && rpcuser != "" {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.bitcoinConfigured = true
            }
            getPeerInfo()
        } else {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.hideSpinner()
                vc.bitcoinConfigured = false
            }
        }
    }

    private func getPeerInfo() {
        command(command: "getpeerinfo") { [weak self] response in
            guard let self = self else { return }
            
            if let peerInfoArray = response as? NSArray {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.mainnetIncomingPeersLabel.stringValue = vc.peerInfo(peerInfoArray).in
                    vc.mainnetOutgoingPeersLabel.stringValue = vc.peerInfo(peerInfoArray).out
                }
            }
            
            self.hideSpinner()
        }
    }

    private func peerInfo(_ peerArray: NSArray) -> (in: String, out: String) {
        var incomingCount = 0
        var outgoingCount = 0
        for peer in peerArray {
            if let peerDict = peer as? NSDictionary {
                if let incoming = peerDict["inbound"] as? Bool {
                    if incoming {
                        incomingCount += 1
                    } else {
                        outgoingCount += 1
                    }
                }
            }
        }
        return ("\(incomingCount)", "\(outgoingCount)")
    }

    func parseBitcoindResponse(result: String) {
        if result.contains("Bitcoin Core Daemon version") || result.contains("Bitcoin Core version") {
            let arr = result.components(separatedBy: "Copyright (C)")
            currentVersion = (arr[0]).replacingOccurrences(of: "Bitcoin Core Daemon version ", with: "")
            currentVersion = currentVersion.replacingOccurrences(of: "Bitcoin Core version ", with: "")
            DispatchQueue.main.async { [unowned vc = self] in
                vc.verifyOutlet.isEnabled = true
                vc.bitcoinCoreVersionOutlet.stringValue = self.currentVersion
                vc.bitcoinInstalled = true
                vc.verifyOutlet.isEnabled = true
            }
            
            isBitcoinOn()
        } else {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.updateOutlet.title = "Install"
                vc.updateOutlet.isEnabled = true
                vc.bitcoinInstalled = false
                vc.verifyOutlet.isEnabled = false
            }
        }
    }

    func parseVerifyResult(result: String) {
        let binaryName = env["BINARY_NAME"] ?? ""
        if result.contains("\(binaryName): OK") {
            simpleAlert(message: "Verified ✓", info: "The sha256 hashes for \(binaryName) and the SHA256SUMS file match.", buttonLabel: "OK")
        } else if result.contains("No ~/.gordian/BitcoinCore directory") {
            simpleAlert(message: "Error", info: "You are using a version of Bitcoin Core which was not installed by GordianServer, we are not yet able to verify Bitcoin Core instances not installed by GordianServer.", buttonLabel: "OK")
        } else {
            simpleAlert(message: "DANGER!!! Invalid signatures...", info: "Please delete the ~/.gordian folder and app and report an issue on the github, hashes do not match.", buttonLabel: "OK")
        }
    }

    //MARK: User Inteface

    private func setTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 15.0, target: self, selector: #selector(automaticRefresh), userInfo: nil, repeats: true)
    }

    @objc func automaticRefresh() {
        refreshAction()
    }

    func setEnv() {
        let chain = UserDefaults.standard.string(forKey: "chain") ?? "main"
        env = ["BINARY_NAME":d.existingBinary(),"VERSION":d.existingPrefix(),"PREFIX":d.existingPrefix(),"DATADIR":d.dataDir(), "CHAIN": chain]
        #if DEBUG
        print("env = \(env)")
        #endif
    }

    func startSpinner(description: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.spinner.startAnimation(vc)
            vc.taskDescription.stringValue = description
            vc.spinner.alphaValue = 1
            vc.taskDescription.alphaValue = 1
        }
    }

    func hideSpinner() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.taskDescription.stringValue = ""
            vc.spinner.stopAnimation(vc)
            vc.spinner.alphaValue = 0
            vc.taskDescription.alphaValue = 0
        }
    }

    func setScene() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.view.backgroundColor = .controlDarkShadowColor
            let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
            switch chain {
            case "main":
                self.networkButton.selectItem(at: 0)
            case "test":
                self.networkButton.selectItem(at: 1)
            case "regtest":
                self.networkButton.selectItem(at: 2)
            case "signet":
                self.networkButton.selectItem(at: 3)
            default:
                break
            }
            self.taskDescription.stringValue = "checking system..."
            self.spinner.startAnimation(self)
            self.icon.wantsLayer = true
            self.icon.layer?.cornerRadius = self.icon.frame.width / 2
            self.icon.layer?.masksToBounds = true
            self.isLoading = true
            self.bitcoinIsOnHeaderImage.image = NSImage(imageLiteralResourceName: "NSStatusUnavailable")
            self.updateOutlet.isEnabled = false
            self.bitcoinCoreVersionOutlet.stringValue = ""
            self.torVersionOutlet.stringValue = ""
            self.startTorOutlet.isEnabled = false
            self.verifyOutlet.isEnabled = false
            self.torRunningImage.alphaValue = 0
            self.bitcoinCoreWindow.backgroundColor = #colorLiteral(red: 0.1605761051, green: 0.1642630696, blue: 0.1891490221, alpha: 1)
            self.torWindow.backgroundColor = #colorLiteral(red: 0.1605761051, green: 0.1642630696, blue: 0.1891490221, alpha: 1)
            self.torAuthWindow.backgroundColor = #colorLiteral(red: 0.2548701465, green: 0.2549202442, blue: 0.2548669279, alpha: 1)
            self.bitcoinCoreWindow.wantsLayer = true
            self.torWindow.wantsLayer = true
            self.torAuthWindow.wantsLayer = true
            self.bitcoinCoreWindow.layer?.borderWidth = 0.75
            self.bitcoinCoreWindow.layer?.cornerRadius = 8
           
            self.torWindow.layer?.borderWidth = 0.75
            self.torWindow.layer?.cornerRadius = 8
            self.torAuthWindow.layer?.borderWidth = 0.75
            self.torAuthWindow.layer?.cornerRadius = 8
            self.bitcoinCoreWindow.layer?.borderColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
            self.torWindow.layer?.borderColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
            self.torAuthWindow.layer?.borderColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
            self.mainnetSyncedLabel.stringValue = ""
            self.mainnetIncomingPeersLabel.stringValue = ""
            self.mainnetOutgoingPeersLabel.stringValue = ""
        }
    }

    func showstandUpAlert(message: String, info: String) {
        DispatchQueue.main.async {
            actionAlert(message: message, info: info) { (response) in
                if response {
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.standingUp = true
                        vc.timer?.invalidate()
                        vc.performSegue(withIdentifier: "goInstall", sender: vc)
                    }
                }
            }
        }
    }

    func setLog(content: String) {
        Log.writeToLog(content: content)
    }

    private func getLatestVersion(completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        FetchLatestRelease.get { [unowned vc = self] (dict, error) in
            if dict != nil {
                if let version = dict!["version"] as? String,
                    let binaryName = dict!["macosBinary"] as? String,
                    let prefix = dict!["binaryPrefix"] as? String {
                    vc.newestPrefix = prefix
                    vc.newestVersion = version
                    vc.newestBinaryName = binaryName
                    completion((true, nil))
                } else {
                    completion((false, error))
                }
            } else {
                completion((false, error))
            }
        }
    }

    private func strap() {
        runScript(script: .launchStrap)
    }
    
    private func installXcodeCLTools() {
        runScript(script: .installXcode)
    }

    // MARK: Segue Prep

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "segueToHelp":
            if let vc = segue.destinationController as? InstallerPrompt {
                vc.text = infoMessage
                vc.headerText = headerText
                vc.isHelp = true
            }
            
        case "segueToInstallXcode":
            if let vc = segue.destinationController as? InstallerPrompt {
                vc.text = infoMessage
                vc.headerText = headerText
                vc.isHelp = false
                
                vc.doneBlock = { response in
                    if response {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.timer?.invalidate()
                            vc.installXcodeCLTools()
                        }
                    }
                }
            }
            
        case "showPairingCode":
            if let vc = segue.destinationController as? QRDisplayer {
                vc.rpcport = rpcport
                vc.network = network
                vc.rpcpassword = rpcpassword
                vc.rpcuser = rpcuser
                vc.torHostname = torHostname
                //vc.httpPass = httpPass
            }

        case "goInstall":
            if let vc = segue.destinationController as? Installer {
                //vc.installLightning = installingLightning
                vc.updatingTor = self.updatingTor
                vc.installingTor = self.installingTor
                vc.standingUp = standingUp
                vc.upgrading = upgrading
                vc.ignoreExistingBitcoin = ignoreExistingBitcoin
                vc.strapping = strapping
                //vc.lightningHostname = lightningP2pHostname
                timer?.invalidate()
                timer = nil
            }

        case "segueToWallets":
            if let vc = segue.destinationController as? WalletsViewController {
                vc.chain = chain
            }
            
        case "segueToInstallPrompt":
            if let vc = segue.destinationController as? InstallerPrompt {
                vc.text = infoMessage
                vc.headerText = headerText
                
                vc.doneBlock = { response in
                    if response {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.standingUp = true
                            vc.timer?.invalidate()
                            vc.performSegue(withIdentifier: "goInstall", sender: vc)
                        }
                    }
                }
            }

        default:
            break
        }
    }
}

extension NSView {
    var backgroundColor: NSColor? {
        get {
            if let colorRef = self.layer?.backgroundColor {
                return NSColor(cgColor: colorRef)
            } else {
                return nil
            }
        }
        set {
            self.wantsLayer = true
            self.layer?.backgroundColor = newValue?.cgColor
        }
    }
}

extension ViewController: OnionManagerDelegate {
    
    func torConnProgress(_ progress: Int) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.taskDescription.stringValue = "Tor bootstrapping \(progress)% complete..."
            vc.updateTorStatus(isOn: false)
        }
    }
    
    func torConnFinished() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.torIsOn = true
            self.torVersionOutlet.stringValue = "v0.4.4.6"
            self.startTorOutlet.title = "Stop"
            self.startTorOutlet.isEnabled = true
            self.updateTorStatus(isOn: true)
            self.checkForGordian()
        }
        
        guard let hostname = mgr?.hostname() else {
            simpleAlert(message: "Tor config issue.", info: "There was an issue fetching your nodes hidden service address. Your node may not be remotely reachable.", buttonLabel: "OK")
            return
        }
        
        self.torConfigured = true
        
        #if DEBUG
        print("hostname: \(hostname)")
        #endif
    }
    
    func torConnDifficulties() {
        self.hideSpinner()
        simpleAlert(message: "Tor connection issue.", info: "We are having trouble starting Tor, your node will not be remotely reachable.", buttonLabel: "OK")
        self.checkForGordian()
    }
}
