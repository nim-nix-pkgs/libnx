import strutils
import libnx/wrapper/acc
import libnx/results
import libnx/wrapper/types
import libnx/ext/integer128
import libnx/service
import libnx/utils

type
  AccountError* = object of Exception
  AccountInitError* = object of AccountError
  AccountImageSizeError* = object of AccountError
  AccountUserProfileError* = object of AccountError
  AccountUserCountError* = object of AccountError
  AccountUserListError* = object of AccountError
  AccountUserNotSelectedError* = object of AccountError
  AccountUserDataError* = object of AccountError
  AccountActiveUserError* = object of AccountError
  AccountImageLoadError* = object of AccountError

  User* = ref object
    id*: u128
    selected*: bool
    username*: string
    lastEdited*: uint64
    iconID*: uint32
    iconBgColorID*: uint8
    miiID*: array[0x10, uint8]

  Profile* = ref object
    service*: Service

  AccountImage* = ref object
    data: seq[uint8]
    imageSize: int

var enabled = false


proc getService*(): Service =
  let serv = accountGetService()[]
  result = newService(serv)


proc init() =
  ## Initializes the account service. Should not
  ## be used in client code
  let service = getService()
  if service.isActive:
    return

  let code = accountInitialize().newResult
  if code.failed:
    raiseEx(
      AccountInitError,
      "Error, account api could not be initialized", code
    )
  enabled = true


proc exit() =
  ## Exits and closes the Account service
  let service = getService()
  if not service.isActive:
    return
  accountExit()
  enabled = false


proc close*(profile: AccountProfile) =
  accountProfileClose(profile.unsafeAddr)


template withAccountService*(code: untyped): typed =
  init()
  code
  exit()


proc ensureEnabled() =
  if not enabled:
    raiseEx(AccountError, "Use withAccountService to access account functions.")


proc getImageSize*(profile: AccountProfile): int =
  ensureEnabled()
  var res = 0.csize
  result = 0
  let code = accountProfileGetImageSize(profile.unsafeAddr, res.addr).newResult
  if code.failed:
    raiseEx(AccountImageSizeError, "Error, could not get image size", code)
  result = res.int


proc imageSize*(user: User): int =
  ensureEnabled()
  var prof: AccountProfile
  var size: csize
  let res = accountProfileGetImageSize(prof.addr, size.addr).newResult

  if res.failed:
    raiseEx(AccountImageSizeError, "Error, could not get image size", res)

  result = size.int


proc getProfileHelper(userID: u128): AccountProfile =
  let res = accountGetProfile(result.addr, userID).newResult

  if res.failed:
    raiseEx(AccountUserProfileError, "Error, could not get user profile", res)


proc loadImage*(user: User): AccountImage =
  ensureEnabled()
  result = new(AccountImage)
  let imSize = user.imageSize()
  var size: csize

  var prof = getProfileHelper(user.id)

  result.data = newSeq[uint8](imSize)

  let res = accountProfileLoadImage(
    prof.addr, result.data[0].addr,
    imSize, result.imageSize.addr
  ).newResult

  if res.failed:
    prof.close()
    raiseEx(AccountImageLoadError, "Error, could not load image", res)

  prof.close()


proc userID*(user: User): string =
  $user.id


proc getUser*(userID: u128): User =
  ensureEnabled()
  result = new(User)

  result.id = userID
  result.selected = false

  var
    prof: AccountProfile = getProfileHelper(userID)
    userData: AccountUserData
    profBase: AccountProfileBase

  let res = accountProfileGet(prof.addr, userData.addr, profBase.addr).newResult

  if res.failed:
    raiseEx(AccountUserDataError, "Error, could not get user data", res)

  result.username = profBase.username.join("")
  result.lastEdited = profBase.lastEditTimestamp
  result.iconID = userData.iconID
  result.iconBgColorID = userData.iconBackgroundColorID
  result.miiID = userData.miiID

  prof.close()


proc getActiveUser*(): User =
  ensureEnabled()
  result = new(User)
  var
    userID: u128 = newUInt128(0,0)
    selected: bool

  var res = accountGetActiveUser(userID.addr, selected.addr).newResult

  if res.failed:
    raiseEx(AccountActiveUserError, "Error, could not get active user ID", res)

  if not selected:
    raiseEx(AccountUserNotSelectedError, "No user currently selected!")

  result.id = userID
  result.selected = selected

  var
    prof: AccountProfile = getProfileHelper(userID)
    userData: AccountUserData
    profBase: AccountProfileBase

  res = accountProfileGet(prof.addr, userData.addr, profBase.addr).newResult

  if res.failed:
    raiseEx(AccountUserDataError, "Error, could not get user data", res)

  result.username = profBase.username.join("")
  result.lastEdited = profBase.lastEditTimestamp
  result.iconID = userData.iconID
  result.iconBgColorID = userData.iconBackgroundColorID
  result.miiID = userData.miiID

  prof.close()


proc getProfile*(user: User): Profile =
  ensureEnabled()
  result = new(Profile)
  var prof: AccountProfile

  let res = accountGetProfile(prof.addr, user.id).newResult
  if res.failed:
    raiseEx(
      AccountUserProfileError,
      "Error, could not get account profile", res
    )

  result.service = newService(prof.s)
  prof.close()


proc getUserCount*(): int32 =
  ## Gets the number of users on the switch
  ensureEnabled()
  var count: int32
  let res = accountGetUserCount(count.addr).newResult
  if res.failed:
    raiseEx(
      AccountUserCountError,
      "Error, could not get user count", res
    )
  result = count


proc listAllUsers*(): seq[User] =
  ## Gets a list of all users currently on the switch
  ensureEnabled()
  result = @[]

  var
    userIDs: array[ACC_USER_LIST_SIZE, u128]
    usersReturned: csize

  let res = accountListAllUsers(
    userIDs[0].addr,
    ACC_USER_LIST_SIZE,
    usersReturned.addr
  ).newResult

  if res.failed:
    raiseEx(
      AccountUserListError,
      "Error, could not list users", res
    )

  for i in 0 ..< usersReturned.int:
    result.add(getUser(userIDs[i]))
