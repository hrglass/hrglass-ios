//
//  ProfileViewController.swift
//  hrglass
//
//  Created by Justin Hershey on 5/11/17.
//
//

import UIKit
import Firebase
import URLEmbeddedView
import AVKit
import AVFoundation
import iOSPhotoEditor


class ProfileViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate,UIImagePickerControllerDelegate, UINavigationControllerDelegate, PostViewDelegate, CropViewControllerDelegate{
    

    let dataManager = DataManager()
    let colors = Colors()
    var progressView: ProgressView!
    var timer: Timer!
    
    
    //DataSource
    var latestPostData:PostData!
    var likedDataArray = [PostData]()
    var ref: DatabaseReference = Database.database().reference()
    var latestPostRef: DatabaseReference!
    var imageCache: ImageCache = ImageCache()
    var awsManager: AWSManager! = nil
    
    //IMPORTANT: Must set currentlyViewingUser and currentlyViewingUID in prepare segue in this VC's parent
    var currentlyViewingUser: User!
    var currentlyViewingUID: String = ""
    var loggedInUser: User!
    var follwBtnIsUnfollow: Bool = false
    var isChoosingProfile: Bool = false
    let imagePicker = UIImagePickerController()
    var moreMenuPostData: PostData!
    
    //table view with one cell
    @IBOutlet weak var profileTableView: UITableView!
    @IBOutlet weak var editBtn: UIButton!
    @IBOutlet weak var coverPhoto: UIImageView!
    
    //default is feed unless other wise specified in discoverVC
    var parentView: String = "feed"
    var cropNavController: UINavigationController!
    
    /*******************************
     *
     *  LIFECYCLE
     *
     *******************************/
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.profileTableView.delegate = self
        self.profileTableView.dataSource = self
        self.imagePicker.delegate = self
        //In case phone is in silent mode
        
        try! AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: [])
        
        self.profileTableView.keyboardDismissMode = UIScrollViewKeyboardDismissMode.onDrag
        
        
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.getProfileData()
    }
    
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //Retrieve User Data
    func getProfileData(){
        //If the current user was set before in prepare for segue
        if currentlyViewingUser != nil{
            
            currentlyViewingUID = (Auth.auth().currentUser?.uid)!
            awsManager = AWSManager(uid: currentlyViewingUID)
            
            
            //pull data from firebase
            self.getLatestPostData()
            self.getLikedPostData()
            
            //SET THE CURRENT USER COVER PHOTO AS BACKGROUND
            if (currentlyViewingUser.coverPhoto != ""){
                
                if dataManager.localPhotoExists(atPath: "coverPhoto"){
                    
                    self.coverPhoto.image = dataManager.getImageForPath(path:"coverPhoto")
                    
                }else{
                    
                    dataManager.syncProfilePhotosToDevice(user: self.currentlyViewingUser, path: "coverPhoto", completion: { image in
                        
                        self.coverPhoto.image = image
                    })
                }
            }else{
                
                self.coverPhoto.image = dataManager.clearImage
                self.view.backgroundColor = UIColor.white
            }
            
            self.profileTableView.reloadData()
            
        }else{
            
            // get user cover photo from backend
            if (currentlyViewingUID != "")
            {
                let userRef = ref.child("Users").child(currentlyViewingUID)
                self.editBtn.isHidden = true
                awsManager = AWSManager(uid: currentlyViewingUID)
                
                userRef.observeSingleEvent(of: .value, with: { snapshot in
                    
                    if let userDict:NSMutableDictionary = snapshot.value as? NSMutableDictionary {
                        
                        self.currentlyViewingUser = self.dataManager.setupUserData(data: userDict, uid: self.currentlyViewingUID)
                        
                        if (self.currentlyViewingUser.coverPhoto != ""){
                            
                            self.imageCache.getImage(urlString: self.currentlyViewingUser.coverPhoto, completion: { image in
                                
                                self.coverPhoto.image = image
                            })
                            
                        }else{
                            
                            self.coverPhoto.image = self.dataManager.clearImage
                            self.view.backgroundColor = UIColor.white
                            
                        }
                        
                        self.profileTableView.reloadData()
                        
                        //PULLED FROM FIREBASE
                        self.getLatestPostData()
                        self.getLikedPostData()
                        
                    }
                })
            }
        }
        
        
    }
    
    
    
    deinit{
        
        self.awsManager = nil
        self.imageCache = ImageCache()
        self.currentlyViewingUser = nil
        self.currentlyViewingUID = ""
        self.likedDataArray = [PostData]()
        
    }
    
    
    
    
    @IBAction func backAction(_ sender: Any) {
        
        if self.parentView == "feed"{
            
            self.performSegue(withIdentifier: "unwindToFeed", sender: self)
        }else if (self.parentView == "discover"){
            
            self.performSegue(withIdentifier: "unwindToDiscover", sender: self)
        }
    }
    
    
    
    
    @IBAction func editAction(_ sender: Any) {
        
        let editAlert: UIAlertController = UIAlertController(title: "Edit Profile Pictures", message: "", preferredStyle: .actionSheet)
        
        //action to edit profile photo
        let profilePhotoAction: UIAlertAction = UIAlertAction(title: "Change Profile Photo", style: .default) { (success) in
            
            print("chose to edit profile picture")
            self.isChoosingProfile = true
            self.imagePicker.allowsEditing = false
            self.imagePicker.sourceType = .photoLibrary
            
            self.presentImagePicker()
        }
        
        //action to edit cover photo
        let coverPhotoAction: UIAlertAction = UIAlertAction(title: "Change Cover Photo", style: .default) { (success) in
            
            print("chose to edit profile picture")
            
            self.isChoosingProfile = false
            self.imagePicker.allowsEditing = false
            self.imagePicker.sourceType = .photoLibrary
            
            self.presentImagePicker()
        }
        
        //action to edit bio
        let editBioAction: UIAlertAction = UIAlertAction(title: "Edit Bio", style: .default) { (success) in
            
            print("chose to bio")
            let indexPath: IndexPath = IndexPath(row: 0, section: 0)
            let cell: ProfileTableViewCell = self.profileTableView.cellForRow(at: indexPath) as! ProfileTableViewCell
            cell.bioTextView.becomeFirstResponder();
            editAlert.dismiss(animated: true, completion: nil)
            
        }
        
        //cancel action
        let cancel: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { (success) in
            
            print("chose to edit profile picture")
            editAlert.dismiss(animated: true, completion: nil)
        }
        
        editAlert.addAction(profilePhotoAction)
        editAlert.addAction(coverPhotoAction)
        editAlert.addAction(editBioAction)
        editAlert.addAction(cancel)
        
        self.present(editAlert, animated: true, completion: nil)
        
    }
    
    
    
    //show image picker for either cover or profile photo
    func presentImagePicker(){
        
        present(self.imagePicker, animated: true, completion: nil)
    }
    
    
    
    //customizable title/message alert
    func postFailedAlert(title: String, message: String){
        
        let alert: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let ok: UIAlertAction = UIAlertAction(title: "Ok", style: .default) {(_) -> Void in
            
            alert.dismiss(animated: true, completion: nil)
            
        }
        
        alert.addAction(ok)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    
    
    //upload cover photo
    func uploadCoverPhoto(completion: @escaping (String) -> ()){
        //always overwrite with same name coverPhoto.jpg
        let imageName: String = "coverPhoto.jpg"
        
        //coverPhoto Ref
        let coverRef = self.ref.child("Users").child(currentlyViewingUser.userID as String)
        
        //image to upload
        let uploadImage: UIImage = self.coverPhoto.image!
        
        //image as data representation
        let data: Data = UIImageJPEGRepresentation(uploadImage, 0.8)! as Data
        
        //Save photo to local documents dir
        dataManager.saveImageForPath(imageData: data, name: "coverPhoto")
        let path = dataManager.documentsPathForFileName(name: "coverPhoto.jpg")
        
        
        //upload to AWS S3
        self.awsManager.uploadPhotoAction(resourceURL: path, fileName: "coverPhoto", type:"jpg", completion:{ success in
            
            if success{
                
                print("Success, upload complete")
                
                //set download url on upload
                let downloadURL: String = String(format:"%@/%@/images/\(imageName)", self.awsManager.getS3Prefix(), self.currentlyViewingUID)
                self.currentlyViewingUser.coverPhoto = downloadURL as String
                coverRef.child("coverPhoto").setValue(downloadURL)
                completion(downloadURL)
                
            }else{
                
                print("Failure, try again?")
                self.postFailedAlert(title: "Post Failed", message: "try again")
                
                return
            }
        })
    }
    
    
    
    
    //Uploads new image data to AWS and sets the download URL in the users profile, if they have an active post, it will set the url in the post data as well
    func uploadProfilePhoto(completion: @escaping (String) -> ()){
        //always overwrite with same name profilePhoto.jpg
        let imageName: String = "profilePhoto.jpg"
        
        //user ref
        let profileRef = self.ref.child("Users").child(currentlyViewingUser.userID as String)
        
        //for profilePhotos, the imagePicker delegate already saves the profile Image to documents. We just need to get the path here
        let path = dataManager.documentsPathForFileName(name: "profilePhoto.jpg")
        
        
        //upload
        self.awsManager.uploadPhotoAction(resourceURL: path, fileName: "profilePhoto", type:"jpg", completion:{ success in
            
            if success{
                
                print("Success, profile photo upload complete")
                
                //store downloadURL
                let downloadURL: String = String(format:"%@/%@/images/\(imageName)", self.awsManager.getS3Prefix(), self.currentlyViewingUID)
                
                
                //if the current user has an active post, set the profile photo
                let postRef = self.ref.child("Posts").child(self.currentlyViewingUser.userID as String)
                postRef.observeSingleEvent(of: .value, with: { (snapshot) in
                    if(snapshot.exists()){
                        postRef.child("user").child("profilePhoto").setValue(downloadURL)
                    }
                })
                
                
                self.currentlyViewingUser.profilePhoto = downloadURL as String
                profileRef.child("profilePhoto").setValue(downloadURL)
                completion(downloadURL)
                
            }else{
                
                print("Failure, try again?")
                self.postFailedAlert(title: "Post Failed", message: "try again")
                
                return
            }
        })
        
    }
    
    
    
    
    /************************
     *
     * IMAGE PICKER DELEGATE
     *
     ***********************/
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            dismiss(animated: true, completion: nil)
            self.presentImageEditorWithImage(image: pickedImage)
        }
    }
    
    
    //On cancel, dismiss picker
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    
    
    
    
    //    func progressUpdateTimer(){
    //
    //        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.photoTimer), userInfo: nil, repeats: true)
    //    }
    //
    //
    //    func photoTimer(){
    //
    //        if (self.progressView.percentageComplete <= 1.0){
    //
    //            self.awsManager.photoUploadProgressCheck()
    //            self.progressView.percentageComplete = CGFloat(self.awsManager.photoUploadProgress)
    //
    //            self.progressView.updateProgress()
    //
    //        }else{
    //
    //            self.timer.invalidate()
    //        }
    //    }
    
    
    
    /*
     * CropView Controller methods
     *
     */
    
    func presentImageEditorWithImage(image:UIImage){
        
        let controller:CropViewController = CropViewController()
        controller.delegate = self
        controller.image = image
        controller.toolbarHidden = true
        controller.keepAspectRatio = true
        
        if isChoosingProfile{
            controller.cropAspectRatio = 1.0
        }else{
            controller.cropAspectRatio = 3.0/5.0
        }
        
        cropNavController = UINavigationController(rootViewController: controller)
        present(cropNavController, animated: true, completion: nil)
        
    }
    
    
    
    func cropViewController(_ controller: CropViewController, didFinishCroppingImage image: UIImage, transform: CGAffineTransform, cropRect: CGRect) {
        if (isChoosingProfile){
            
            let indexPath: IndexPath = IndexPath(row: 0, section: 0)
            let cell: ProfileTableViewCell = self.profileTableView.cellForRow(at: indexPath) as! ProfileTableViewCell
            
            cell.profilePhoto.contentMode = .scaleAspectFill
            cell.profilePhoto.image = image
            let data: Data = UIImageJPEGRepresentation(image, 0.8)! as Data
            dataManager.saveImageForPath(imageData: data, name: "profilePhoto")
            
//            self.profileTableView.reloadData()

            self.uploadProfilePhoto(completion: { (url) in
                print(url)
                
                self.imageCache.replacePhotoForKey(url: url, image: image)

            })
            
        }else{
            
            coverPhoto.contentMode = .scaleAspectFill
            coverPhoto.image = image
            self.uploadCoverPhoto(completion: { (url) in
                print(url)
                self.imageCache.replacePhotoForKey(url: url, image: image)
            })
        }
        
        cropNavController.dismiss(animated: true, completion: nil)
    }
    
    func cropViewControllerDidCancel(_ controller: CropViewController) {
        print("Canceled")
        cropNavController.dismiss(animated: true, completion: nil)
    }
    
    
    
    
    /******************************************************************************
     *
     *      Latest Post DATA RETRIEVAL
     *      -- sets self.latestPostData to nil if the post is expired
     *****************************************************************************/
    
    func getLatestPostData(){
        
        if (currentlyViewingUser != nil){
            
            let uid = self.currentlyViewingUID
            latestPostRef = ref.child("Posts").child(uid)
            
            latestPostRef.observeSingleEvent(of: .value, with: { snapshot in
                
                if let postData: NSDictionary = snapshot.value as? NSDictionary {
                    
                    if let _: NSMutableDictionary = postData.value(forKey: "liked_by_list") as? NSMutableDictionary{
                        
                        
                        self.latestPostData = self.dataManager.getPostDataFromDictionary(postDict: postData, uid: uid)
                        if (Double(self.latestPostData.expireTime)! < Date().millisecondsSince1970) {
                            
                            self.latestPostData = nil
                        }else{
                            self.latestPostData.category = Category(rawValue: postData.value(forKey: "category") as! String)!
                        }
                        
                        
                    }else{
                        
                        postData.setValue([:], forKey: "liked_by_list")
                        self.latestPostData = self.dataManager.getPostDataFromDictionary(postDict: postData, uid: uid)
                        if (Double(self.latestPostData.expireTime)! < Date().millisecondsSince1970) {
                            
                            self.latestPostData = nil
                        }else{
                            self.latestPostData.category = Category(rawValue: postData.value(forKey: "category") as! String)!
                        }
                    }

                    self.profileTableView.reloadData()
                    
                } else{
                    
                    //NO Post Data
                    print("No Recent Post Data")
                    
                }
            })
        }
    }
    
    
    /**********************************
     *
     * TABLE VIEW DELEGATE METHODS
     *
     **********************************/
    
    //We use a tableView with the profile as one cell so we can use a horizonantal collection view and still be
    //able to scroll vertically -- however, for now I've disabled collection view scrolling as I'm not sure we want it
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell: ProfileTableViewCell = profileTableView.dequeueReusableCell(withIdentifier: "profileCell") as! ProfileTableViewCell
        cell.bioTextView.delegate = self
        
        //remove liked post if it isn't an active post
        cell.messageBtn.layer.cornerRadius = 3.0
        cell.messageBtn.layer.borderWidth = 1.0
        cell.messageBtn.layer.borderColor = self.colors.getMenuColor().cgColor
        
        cell.likedDataArray = self.likedDataArray
        
        if currentlyViewingUser != nil{
            
            cell.nameLbl.text = currentlyViewingUser.name as String
            
            if(currentlyViewingUser.bio as String == ""){
                
                cell.bioTextView.text = "Write about yourself..."
                cell.bioTextView.textColor = UIColor.lightGray
                
            }else{
                cell.bioTextView.text = currentlyViewingUser.bio as String
            }
            
            self.adjustUITextViewHeight(arg: cell.bioTextView)
            
            cell.postsUserLikedLbl.text = String(format: "Content %@ liked", currentlyViewingUser.name)
            
            //HIDE FOLLOW BUTTON IF VIEWING YOUR OWN PROFILE
            if(currentlyViewingUser.userID as String == Auth.auth().currentUser?.uid){
                cell.followBtn.isHidden = true
                cell.bioTextView.isUserInteractionEnabled = true
                cell.messageBtn.isHidden = true
            }else{
                
                cell.bioTextView.isUserInteractionEnabled = false
                
                //we want the follow button to say unfollow if it comes from the feed or if we are already following them
                if (follwBtnIsUnfollow ){
                    
                    cell.followBtn.setTitle("Unfollow", for: .normal)
                    cell.followBtn.setTitleColor(colors.getMenuColor(), for: .normal)
                    cell.followBtn.backgroundColor = UIColor.clear
                    
                }else{
                    
                    cell.followBtn.backgroundColor = colors.getMenuColor()
                }
            }
        }
        
        cell.followBtn.layer.cornerRadius = 5.0
        cell.followBtn.layer.borderColor = colors.getMenuColor().cgColor
        cell.followBtn.layer.borderWidth = 1
        cell.latestPostBackground.layer.cornerRadius = cell.latestPostBackground.frame.width / 2
        cell.latestPostImageButton.layer.cornerRadius = cell.latestPostImageButton.frame.width / 2
        cell.latestPostBackground.layer.borderWidth = 5.0
        cell.latestPostImageButton.clipsToBounds = true
        cell.latestPostImageButton.setBackgroundImage(dataManager.clearImage, for: .normal)
        cell.postIndicator.startAnimating()
        cell.profilePictureIndicator.startAnimating()
        cell.bioTextView.textColor = UIColor.white
        cell.user = self.currentlyViewingUser
        cell.likedCollectionView.reloadData()
        
        
        if self.latestPostData != nil{
            
            cell.latestPostBackground.isHidden = false
            cell.latestPostImageButton.isHidden = false
            cell.playImageView.isHidden = true
            cell.noRecentPostsLbl.isHidden = true
            cell.latestPostBackground.layer.borderColor = self.dataManager.getUIColorForCategory(category: self.latestPostData.category).cgColor
            
            //use enum switch to determine UIImageView Image
            switch self.latestPostData.category {
                
            case .Link:
                
                dataManager.setURLView(urlString: latestPostData.data as String, completion: { (image, label) in
                    
                    cell.latestPostImageButton.setBackgroundImage(image, for: .normal)
                    
                    let linkLabel = UILabel(frame: CGRect(x: cell.latestPostImageButton.bounds.minX, y:cell.latestPostImageButton.bounds.midY, width: cell.latestPostImageButton.frame.width ,height: cell.latestPostImageButton.frame.height/3))
                    
                    linkLabel.adjustsFontSizeToFitWidth = true
                    linkLabel.numberOfLines = 3
                    linkLabel.backgroundColor = UIColor.darkGray
                    linkLabel.alpha = 0.7
                    linkLabel.text = label
                    linkLabel.textAlignment = .center
                    linkLabel.textColor = UIColor.white
                    
                    cell.latestPostImageButton.addSubview(linkLabel)
                    cell.postIndicator.stopAnimating()
                    
                })
                
                
            case .Music:
                
                print("Music")
                let thumbnailURL: String = String(format:"%@/%@/images/thumbnail.jpg", self.awsManager.getS3Prefix(), currentlyViewingUID)
                
                self.imageCache.getImage(urlString: thumbnailURL, completion: { image in
                    
                    cell.latestPostImageButton.setBackgroundImage(image, for: .normal)
                    cell.playImageView.isHidden = false
                    cell.postIndicator.stopAnimating()
                    
                })
                
            case .Video:
                
                let thumbnailURL: String = String(format:"%@/%@/images/thumbnail.jpg", self.awsManager.getS3Prefix(), currentlyViewingUID)
                
                self.imageCache.getImage(urlString: thumbnailURL, completion: { image in
                    
                    cell.latestPostImageButton.setBackgroundImage(image, for: .normal)
                    cell.playImageView.isHidden = false
                    cell.postIndicator.stopAnimating()
                    
                })
                
                
            case .Photo:
                
                self.imageCache.getImage(urlString: latestPostData.data, completion: { image in
                    
                    cell.latestPostImageButton.setBackgroundImage(image, for: .normal)
                    cell.postIndicator.stopAnimating()
                    
                })
                
                
            case .Recording:
                
                print("Recording")
                cell.latestPostImageButton.setBackgroundImage(UIImage(named:"audioWave"), for: .normal)
                cell.playImageView.isHidden = false
                
                
            case .Text:
                
                print("Text")
                self.imageCache.getImage(urlString: latestPostData.data, completion: { image in
                    
                    cell.latestPostImageButton.setBackgroundImage(image, for: .normal)
                    cell.postIndicator.stopAnimating()
                    
                })
            default:
                print("default")
                
            }
            
        }else{
            
            cell.latestPostBackground.isHidden = true
            cell.latestPostImageButton.isHidden = true
            cell.noRecentPostsLbl.isHidden = false
            
        }
        
        
        if (currentlyViewingUser != nil){
            
            if (currentlyViewingUser.bio == ""){
                
                cell.bioTextView.frame.size = CGSize(width: cell.bioTextView.frame.width, height:0)
            }
            
            
            if (currentlyViewingUser.profilePhoto != ""){
                
                if currentlyViewingUID == Auth.auth().currentUser?.uid{
                    
                    cell.profilePhoto.image = dataManager.getImageForPath(path:"profilePhoto")
                    cell.profilePictureIndicator.stopAnimating()
                    
                }else{
                    
                    self.imageCache.getImage(urlString: self.currentlyViewingUser.profilePhoto, completion: { image in
                        
                        cell.profilePhoto.image = image
                        cell.profilePictureIndicator.stopAnimating()
                        
                    })
                }
            }else{
                
                cell.profilePhoto.image = dataManager.defaultsUserPhoto
                cell.profilePictureIndicator.stopAnimating()
            }
            
            cell.profilePhoto.layer.cornerRadius = cell.profilePhoto.frame.width / 2
            cell.profilePhoto.clipsToBounds = true
            
            let followedByCountRef: DatabaseReference = self.ref.child("FollowedBy").child(currentlyViewingUID).child("followed_by_count")
            let followingCountRef: DatabaseReference = self.ref.child("Following").child(currentlyViewingUID).child("following_count")
            
            followedByCountRef.observeSingleEvent(of: .value, with: { (snapshot) in
                
                if (snapshot.exists()){
                    cell.followerLbl.text = String(describing: snapshot.value as! NSInteger)
                }else{
                    cell.followerLbl.text = "0"
                }
                
            })
            
            
            followingCountRef.observeSingleEvent(of: .value, with: { (snapshot) in
                if (snapshot.exists()){
                    cell.followingLbl.text = String(describing: snapshot.value as! NSInteger)
                }else{
                    cell.followingLbl.text = "0"
                }
                
            })
        }
        
        
        
        //Uses the selectedCellRow property of ProfileTableViewCell which will contain the selected cell row
        // to get the correct likedDataArray object
        cell.collectionContentSelected = {
            
            let collCellData: PostData = self.likedDataArray[cell.selectedCellRow]
            
            let postVC: PostViewController = self.storyboard!.instantiateViewController(withIdentifier: "postViewController") as! PostViewController
            
            postVC.delegate = self
            postVC.imageCache = self.imageCache
            postVC.postData = collCellData
            postVC.source = "Profile"
            
            //just pass a selected IndexPath so it isn't empty
            postVC.selectedIndexPath = IndexPath(row: 0, section: 0)
            
            self.addChildViewController(postVC)
            
            postVC.view.frame = self.view.bounds
//            postVC.topGradientView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            
            self.view.addSubview(postVC.view)
            postVC.didMove(toParentViewController: self)
        }
        
        
        //Action that is called when the latest post is selected
        cell.latestContentSelected = {
            
            let postVC: PostViewController = self.storyboard!.instantiateViewController(withIdentifier: "postViewController") as! PostViewController
            postVC.selectedIndexPath = IndexPath(row: 0, section: 0)
            postVC.delegate = self
            postVC.imageCache = self.imageCache
            postVC.postData = self.latestPostData
            postVC.source = "Profile"
            
            self.addChildViewController(postVC)
            
            postVC.view.frame = self.view.bounds
            
            self.view.addSubview(postVC.view)
            postVC.didMove(toParentViewController: self)
        }
        
        //action when the message button is selected
        cell.messageBtnSelected = {
            
            self.performSegue(withIdentifier: "toMessagesView", sender: self)
            
        }
        
        return cell
    }
    
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return 1
    }
    
    
    
    /****************************
     *
     * LIKED POSTS DATA RETRIEVE
     *
     ****************************/
    
    func getLikedPostData(){
        
        let currentUserId = self.currentlyViewingUID
        
        let likedRef = Database.database().reference().child("Users").child(currentUserId).child("liked_posts")
        let postRef = Database.database().reference().child("Posts")
        
        likedRef.observeSingleEvent(of: .value, with: { snapshot in
            
            if let likedPosts: NSDictionary = snapshot.value as? NSDictionary
            {
                
                //remove expired posts
                let trimmedPosts: NSMutableDictionary = NSMutableDictionary()
                
                for (key, expireTime) in likedPosts{
                    let expired: Double = Double(expireTime as! String)!
                    let now: Double = Date().millisecondsSince1970
                    
                    if expired > now{
                        trimmedPosts.setValue(expireTime, forKey: key as! String)
                    }
                }
                
                //count non-expired posts
                let totalCount: Int = trimmedPosts.count
                var i: Int = 0
                
                for (key, _) in trimmedPosts{
                    
                    let postUserId = key as! String
                    
                    postRef.child(postUserId).observeSingleEvent(of: .value, with: { postSnapshot in
                        
                        if let post: NSDictionary = postSnapshot.value as? NSDictionary{
                            
                            let postData: PostData = self.dataManager.getPostDataFromDictionary(postDict: post, uid: key as! String)
                            
                            if (Double(postData.expireTime)! > Date().millisecondsSince1970) {
                                
                                self.likedDataArray.append(self.dataManager.getPostDataFromDictionary(postDict: post, uid: key as! String))
                            }
                            
                            i += 1
                            if (i == totalCount){
                                self.profileTableView.reloadData()
                                
                            }
                        }
                    })
                }
            }
        })
    }
    
    
    
    //Post View Delegates
    //the user has just touched the liked button. If liked is true, the user has liked the photo. If false, unliked
    func likedButtonPressed(liked: Bool, indexPath: IndexPath) {
        
        
        //update UI
        // nothing
        
    }
    
    
    
    func moreButtonPressed(data: PostData, indexPath: IndexPath) {
        
        let fullname: String = data.user.value(forKey: "name") as! String
        
        let alert: UIAlertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let block: UIAlertAction = UIAlertAction(title: String(format:"Block %@", self.dataManager.getFirstName(name: fullname)) , style: .default) {(_) -> Void in
            
            self.moreMenuPostData = data
            self.blockUserAction()
            alert.dismiss(animated: true, completion: nil)
        }
        
        let message: UIAlertAction = UIAlertAction(title: String(format:"Send %@ a Message", self.dataManager.getFirstName(name: fullname)) , style: .default) {(_) -> Void in
            
            self.moreMenuPostData = data
            let cell: ProfileTableViewCell = self.profileTableView.cellForRow(at: indexPath) as! ProfileTableViewCell
            
            cell.messageAction(self)
            alert.dismiss(animated: true, completion: nil)
        }
        
        let delete: UIAlertAction = UIAlertAction(title: String(format:"Expire Post", self.dataManager.getFirstName(name: fullname)) , style: .default) {(_) -> Void in
            //set the expire time to the post creation time
            let ref: DatabaseReference = Database.database().reference().child("Posts").child((Auth.auth().currentUser?.uid)!).child("expire_time")
            ref.setValue(data.creationDate)
            
            alert.dismiss(animated: true, completion: nil)
        }
        
        
        
        let cancel: UIAlertAction = UIAlertAction(title: "Cancel" , style: .cancel) {(_) -> Void in
            alert.dismiss(animated: true, completion: nil)
        }
        
        
        if (data.user.value(forKey: "uid") as? String  == Auth.auth().currentUser?.uid){
            
            alert.addAction(delete)
        }else{
            alert.addAction(message)
            alert.addAction(block)
            
        }
        
        alert.addAction(cancel)
        
        self.present(alert, animated: true, completion: nil)
        
        
    }
    
    func blockUserAction(){
        
        //don't do anything
        print(String(format:"Block User (%@) Action", self.moreMenuPostData))
        self.dataManager.blockUser(postData: self.moreMenuPostData)
        self.performSegue(withIdentifier: "unwindToFeedSegue", sender: self)
        
        
    }
    
    //Will play a video
    //    func playURLData(url: URL){
    //
    //        let player=AVPlayer(url: url)
    //
    //        let avPlayerViewController = AVPlayerViewController()
    //        avPlayerViewController.player =  player
    //
    //        self.present(avPlayerViewController, animated: true) {
    //            avPlayerViewController.player!.play()
    //        }
    //    }
    //
    
    
    /******************************
     *
     *  -- Text View Delegates --
     *
     ****************************/
    
    
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        textView.frame.size = CGSize(width: self.view.frame.width - 95 - textView.frame.minX, height:textView.frame.size.height)
        return true
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        
        //change background and text
        textView.backgroundColor = UIColor.white
        textView.textColor = UIColor.black
    }
    
    
    func textViewDidEndEditing(_ textView: UITextView) {
        
        //save bio abd revert color scheme
        textView.backgroundColor = UIColor.clear
        textView.textColor = UIColor.white
        self.currentlyViewingUser.bio = textView.text
        self.ref.child("Users").child((Auth.auth().currentUser?.uid)!).child("bio").setValue(textView.text)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if(text == "\n") {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
    
    
    func textViewDidChange(_ textView: UITextView) {
        let numLines: Int = Int(textView.contentSize.height / textView.font!.lineHeight);
        
        //adjust textview height based on the number of lines
        if numLines > 1{
            self.adjustUITextViewHeight(arg: textView)
        }else {
            textView.isScrollEnabled = true
        }
    }
    
    
    //auto adjust bio textView height
    func adjustUITextViewHeight(arg : UITextView)
    {
        arg.translatesAutoresizingMaskIntoConstraints = true
        arg.sizeToFit()
        arg.frame.size = CGSize(width: self.view.frame.width - 95 - arg.frame.minX, height:arg.frame.size.height)
        arg.isScrollEnabled = false
    }
    
    
    
    /**********************
     *
     *  -- NAVIGATION --
     *
     **********************/
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        //        if segue.identifier == "toAllPostsSegue"{
        //
        //            let vc: AllPostsViewController = segue.destination as! AllPostsViewController
        //
        //            vc.postsArray = self.postDataArray
        //
        //        }else
        //
        if(segue.identifier == "toAllLikedSegue"){
            
            let vc = segue.destination as! AllPostsViewController
            
            vc.postsArray = self.likedDataArray
            vc.imageCache = self.imageCache
            
        }else if(segue.identifier == "unwindToFeedSegue"){
            
            let vc = segue.destination as! FeedViewController
            
            if currentlyViewingUser.userID == Auth.auth().currentUser?.uid{
                vc.loggedInUser = self.currentlyViewingUser
            }
            
            vc.imageCache = self.imageCache
            
        }else if (segue.identifier == "toMessagesView"){
            
            let vc = segue.destination as? MessagesViewController
            vc?.parentView = "profile"
            vc?.selectedUserId = self.currentlyViewingUser.userID
            vc?.loggedInUser = self.loggedInUser
        }
    }
    
    
    @IBAction func unwindToProfile(unwindSegue: UIStoryboardSegue) {
        
        
    }
    
}
