#Region
#AutoIt3Wrapper_UseX64=y
#EndRegion

#include "Libs\autoit-opencv-com\udf\opencv_udf_utils.au3"
#include <GDIPlus.au3>
#include <GUIConstantsEx.au3>
#include <ScreenCapture.au3>
#include <StaticConstants.au3>
#include <WinAPI.au3>


; client size: 1280x720
; window size: 1282x759
; gui size: 1298x767


DllCall("user32.dll", "bool", "SetProcessDPIAware")
Local $arrDPIs = DllCall("user32.dll", "uint", "GetDpiForSystem") ; Windows 10+
Local $iWinScale = $arrDPIs[0] / 96 ; DPI 96 is 100%

_OpenCV_Open("Libs\opencv\build\x64\vc16\bin\opencv_world4120.dll", "Libs\autoit-opencv-com\autoit_opencv_com4120.dll")
_GDIPlus_Startup()
OnAutoItExitRegister("_OnAutoItExit")

Global $sGameWinTitle   = "マブラヴ"
Global $sGameResDir     = @ScriptDir & "\Res\MuvLuv\"
Global $sScriptLog      = @ScriptDir & "\Game_MuvLuv.log"
Global $iLoopTimer      = 500

Global $bMazeFarmingOn  = True
Global $bMazeCraftSkip  = True

Global $bWriteLogOn     = False
Global $bRunning        = False
Global $bPausing        = False
Global $iPausingTimer   = 0
Global $iPausingMax     = $iLoopTimer
Global $bSingleRunning  = False

Global $cv = _OpenCV_get()
If Not IsObj($cv) Then
    MsgBox(16, "Error", "Failed to get OpenCV COM object.")
    Exit
EndIf


; The theme
Global $bIsDark = False
Global $c_Dark_BG       = 0x1F1F1F, $c_Dark_Text      = 0xF0F0F0
Global $c_Light_BG      = 0xF3F3F3, $c_Light_Text     = 0x000000
Global $c_Status_BG     = 0x000000, $c_Status_Text    = 0xFFFFFF
Global $aThemeControls[20], $iCtrlCount = 0

Func _RegisterThemeCtrl($iCtrlID)
    $aThemeControls[$iCtrlCount] = $iCtrlID
    $iCtrlCount += 1
EndFunc

; The font and size.
Local $sFont = "Segoe UI"
Local $iFontSize = 10
Local $iGUIWidth = Int(255 * $iWinScale), $iGUIHeight = Int(255 * $iWinScale)

Local $hGUI = GUICreate("MuvLuv Auto", $iGUIWidth, $iGUIHeight)
GUISetFont($iFontSize, $FW_NORMAL, 0, $sFont)

; [ Normal, Hover, Clicked ] Colors
Global $aBtnColor_Dark[3]  = [0x333333, 0x444444, 0x222222]
Global $aBtnColor_Light[3] = [0xE1E1E1, 0xD0D0D0, 0xB8B8B8]
Global $bBtnHovered = False
Local $iBtnW = Int(100 * $iWinScale), $iBtnH = Int(40 * $iWinScale)
;Local $btnStart = GUICtrlCreateButton("Start", Int(($iGUIWidth - $iBtnW) / 2), Int(10 * $iWinScale), $iBtnW, $iBtnH)
Global $btnStart = GUICtrlCreateLabel("Start", Int(($iGUIWidth - $iBtnW) / 2), Int(10 * $iWinScale), $iBtnW, $iBtnH, BitOR($SS_CENTER, $SS_CENTERIMAGE))
GUICtrlSetFont($btnStart, 11, $FW_BOLD, 0, $sFont)

Local $iPadTop = 3
Local $iStatusW = Int(120 * $iWinScale), $iStatusH = Int(25 * $iWinScale) - $iPadTop
Local $iStatusX = Int(($iGUIWidth - $iStatusW) / 2)
Local $iStatusY = Int(10 * $iWinScale) + $iBtnH + Int(10 * $iWinScale) ; 合并 Gap 运算

Local $lblStatusPad = GUICtrlCreateLabel("", $iStatusX, $iStatusY, $iStatusW, $iPadTop)
GUICtrlSetBkColor($lblStatusPad, 0x000000)
; Initial string length needs attention.
Global $lblStatus = GUICtrlCreateLabel("  Status: Idle    ", $iStatusX, $iStatusY + $iPadTop, $iStatusW, $iStatusH)
GUICtrlSetBkColor($lblStatus, 0x000000)
GUICtrlSetColor($lblStatus, 0xFFFFFF)

Local $iTipsW = Int(235 * $iWinScale), $iTipsH = Int(20 * $iWinScale)
Local $iTipsX = Int(($iGUIWidth - $iTipsW) / 2)
Local $iTipsY = $iStatusY + $iStatusH + Int(10 * $iWinScale)
Local $iTipsGap = $iTipsH + Int(5 * $iWinScale)

Local $aTipsText[3] = [ _
    "Tip1: Press Esc/End to stop looping.", _
    "Tip2: Keep an eye on the game.", _
    "Tip3: Client size 1280x720." _
]
For $i = 0 To 2
    Local $hIdTip = GUICtrlCreateLabel($aTipsText[$i], $iTipsX, $iTipsY + ($i * $iTipsGap), $iTipsW, $iTipsH)
    _RegisterThemeCtrl($hIdTip)
Next

Local $iChkBoxW = Int(18 * $iWinScale)
Local $iChkBoxP = Int(1 * $iWinScale)

Local $iChkDebugW = Int(100 * $iWinScale), $iChkDebugH = Int(20 * $iWinScale)
Local $iChkDebugY = $iGUIHeight - Int(25 * $iWinScale)
Local $iChkDebugX = Int(($iGUIWidth - $iChkDebugW) / 2)
Local $chkDebug = GUICtrlCreateCheckbox("", $iChkDebugX, $iChkDebugY, $iChkBoxW, $iChkDebugH)
Local $chkDebugText = GUICtrlCreateLabel("Enable log", $iChkDebugX + $iChkBoxW, $iChkDebugY + $iChkBoxP, $iChkDebugW - $iChkBoxW, $iChkDebugH)
_RegisterThemeCtrl($chkDebugText)

Local $iChkMazeW = Int(150 * $iWinScale), $iChkMazeH = Int(20 * $iWinScale)
Local $iChkMazeY = $iChkDebugY - Int(25 * $iWinScale)
Local $iChkMazeX = Int(($iGUIWidth - $iChkMazeW) / 2)
Local $chkMazeFarming = GUICtrlCreateCheckbox("", $iChkMazeX, $iChkMazeY, $iChkBoxW, $iChkMazeH)
Local $chkMazeFarmingText = GUICtrlCreateLabel("Enable Maze Farming", $iChkMazeX + $iChkBoxW, $iChkMazeY + $iChkBoxP, $iChkMazeW - $iChkBoxW, $iChkMazeH)
GUICtrlSetState($chkMazeFarming, $GUI_CHECKED)
_RegisterThemeCtrl($chkMazeFarmingText)

Local $iChkCraftW = Int(150 * $iWinScale), $iChkCraftH = Int(20 * $iWinScale)
Local $iChkCraftY = $iChkMazeY - Int(25 * $iWinScale)
Local $iChkCraftX = Int(($iGUIWidth - $iChkCraftW) / 2)
Local $chkCraftSkip = GUICtrlCreateCheckbox("", $iChkCraftX, $iChkCraftY, $iChkBoxW, $iChkCraftH)
Local $chkCraftSkipText = GUICtrlCreateLabel("Skip Crafting in Maze", $iChkCraftX + $iChkBoxW, $iChkCraftY + $iChkBoxP, $iChkCraftW - $iChkBoxW, $iChkCraftH)
GUICtrlSetState($chkCraftSkip, $GUI_CHECKED)
_RegisterThemeCtrl($chkCraftSkipText)

; Listen to the theme change
GUIRegisterMsg(0x001A, "WM_SETTINGCHANGE")
_ApplySystemTheme($hGUI)

Func WM_SETTINGCHANGE($hWnd, $iMsg, $wParam, $lParam)
    _ApplySystemTheme($hGUI)
    Return $GUI_RUNDEFMSG
EndFunc

Func _ApplySystemTheme($hWnd)
    Local $iReg = RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")

    If @error Then Return

    Local $bCurrentIsDark = ($iReg == 0)
    $bIsDark = $bCurrentIsDark

    Local $cBkColor = $bIsDark ? $c_Dark_BG : $c_Light_BG
    Local $cTextColor = $bIsDark ? $c_Dark_Text : $c_Light_Text

    GUISetBkColor($cBkColor, $hWnd)

    ; Button theme
    Local $aCurrentBtnSrc = $bIsDark ? $aBtnColor_Dark : $aBtnColor_Light
    GUICtrlSetBkColor($btnStart, $aCurrentBtnSrc[0])
    GUICtrlSetColor($btnStart, $bIsDark ? 0xFFFFFF : 0x000000)

    ; Ctrl theme
    For $i = 0 To $iCtrlCount - 1
        Local $hIdCtrl = $aThemeControls[$i]
        GUICtrlSetColor($hIdCtrl, $cTextColor)
        GUICtrlSetBkColor($hIdCtrl, $cBkColor)
    Next

    Local $pDark = DllStructCreate("int")
    DllStructSetData($pDark, 1, $bIsDark ? 1 : 0)
    DllCall("dwmapi.dll", "long", "DwmSetWindowAttribute", "hwnd", $hWnd, "dword", 20, "ptr", DllStructGetPtr($pDark), "dword", 4)
EndFunc

$iBtnLeft   = -1
$iBtnTop    = -1
$iBtnRight  = -1
$iBtnBottom = -1

; GUI Start
GUISetState(@SW_SHOW)
HotKeySet("{ESC}", "ActionStop")
HotKeySet("{END}", "ActionStop")
While True
    Local $aMousePos = GUIGetCursorInfo($hGUI)
    If Not @error Then
        Local $iMX = $aMousePos[0]
        Local $iMY = $aMousePos[1]
        Local $aColors = $bIsDark ? $aBtnColor_Dark : $aBtnColor_Light

        If $iBtnLeft = -1 Then
            Local $aBtnPos = ControlGetPos($hGUI, "", $btnStart)
            $iBtnLeft   = $aBtnPos[0]
            $iBtnTop    = $aBtnPos[1]
            $iBtnRight  = $aBtnPos[0] + $aBtnPos[2]
            $iBtnBottom = $aBtnPos[1] + $aBtnPos[3]
        EndIf

        If ($iMX >= $iBtnLeft And $iMX <= $iBtnRight) And ($iMY >= $iBtnTop And $iMY <= $iBtnBottom) Then
            If Not $bBtnHovered Then
                $bBtnHovered = True
                GUICtrlSetBkColor($btnStart, $aColors[1])
            EndIf
        Else
            If $bBtnHovered Then
                $bBtnHovered = False
                GUICtrlSetBkColor($btnStart, $aColors[0])
            EndIf
        EndIf
    EndIf

    Switch GUIGetMsg()
        ; When click close button
        Case $GUI_EVENT_CLOSE
            Exit
        Case $btnStart
            Local $aColors = $bIsDark ? $aBtnColor_Dark : $aBtnColor_Light
            GUICtrlSetBkColor($btnStart, $aColors[2])
            Sleep(80)
            GUICtrlSetBkColor($btnStart, $aColors[1])
            If $bRunning Then
                ActionStop()
            Else
                ActionStart()
            EndIf

        ; The check boxes
        Case $chkDebug
            $bWriteLogOn = (GUICtrlRead($chkDebug) = $GUI_CHECKED)

        Case $chkMazeFarming
            $bMazeFarmingOn = (GUICtrlRead($chkMazeFarming) = $GUI_CHECKED)

        Case $chkCraftSkip
            $bMazeCraftSkip = (GUICtrlRead($chkCraftSkip) = $GUI_CHECKED)
    EndSwitch
WEnd

; Functions
Func ResetPausingState()
    $bPausing = False
    $iPausingTimer = 0
    $iPausingMax = 0
EndFunc

Func ActionStart()
    GUICtrlSetData($btnStart, "Stop")
    GUICtrlSetData($lblStatus, "  Status: Running ")
    GUICtrlSetColor($lblStatus, 0x00FF00)
    $bRunning = True
    AdlibRegister("AutoClick", $iLoopTimer)
EndFunc

Func ActionStop()
    GUICtrlSetData($btnStart, "Start")
    GUICtrlSetData($lblStatus, "  Status: Idle    ")
    GUICtrlSetColor($lblStatus, 0xFFFFFF)
    $bRunning = False
    ResetPausingState()
    AdlibUnRegister("AutoClick")
EndFunc

Func ActionContinue()
    If Not $bRunning Then Return
    GUICtrlSetData($lblStatus, "  Status: Running ")
    GUICtrlSetColor($lblStatus, 0x00FF00)
    ResetPausingState()
EndFunc

Func ActionPause($iMilliSeconds)
    GUICtrlSetData($lblStatus, "  Status: Waiting ")
    GUICtrlSetColor($lblStatus, 0xFFD966)
    $iPausingTimer = 0
    $iPausingMax = $iMilliSeconds
    $bPausing = True
EndFunc

Func _WinAPI_GetClientPos($hWnd)
    If Not IsHWnd($hWnd) Then $hWnd = WinGetHandle($hWnd)
    If Not $hWnd Then Return False

    Local $tRect = _WinAPI_GetClientRect($hWnd)
    If @error Then Return False

    Local $tPoint = DllStructCreate("long X;long Y")
    DllStructSetData($tPoint, "X", 0)
    DllStructSetData($tPoint, "Y", 0)
    _WinAPI_ClientToScreen($hWnd, DllStructGetPtr($tPoint))
    If @error Then Return False

    Local $aPos[4]
    $aPos[0] = DllStructGetData($tPoint, "X") ; Left
    $aPos[1] = DllStructGetData($tPoint, "Y") ; Top
    $aPos[2] = DllStructGetData($tRect, "Right") ; Width
    $aPos[3] = DllStructGetData($tRect, "Bottom") ; Height
    Return $aPos
EndFunc

; Image Search Functions.
; #FUNCTION# ==========================================================================================================
; Name ..........: ImageSearch
; Description ...: Find image in the game client or subarea relative to the game client.
; Syntax ........: ImageSearch($sImageFile[, $fThreshold = 0.8[, $arrSubArea = Default[, $iBaseClientHeight = 720]]])
; Parameters ....: $sImageFile      - Image path.
;                  $fThreshold      - [optional] The threshold. Default is 0.8
;                  $arrSubArea      - [optional] The sub area [x, y, w, h] relative to the game client. Default is the
;                                                whole game client.
;                  $iBaseClientHeight - [optional] The base game client height where you capture the template images. So
;                                                the captured images should be capture in the same client size. If the
;                                                running game client size is different, the template image will be
;                                                resized proportionally to match the client size. Though it's better
;                                                to keep your game client size consistent.
; Return values .: Array of area relative to the game client if find or subarea if provided. Otherwise just silent.
; =====================================================================================================================
Func ImageSearch($sImageFile, $fThreshold = 0.8, $arrSubArea = Default, $iBaseClientHeight = 720)
    Local $imgTempl = _OpenCV_imread_and_check($sImageFile)

    Local $arrArea = _WinAPI_GetClientPos($sGameWinTitle)
    Local $iActualHeight = $arrArea[3]
    If $arrSubArea <> Default Then
        $arrArea[0] += $arrSubArea[0]
        $arrArea[1] += $arrSubArea[1]
        $arrArea[2] = $arrSubArea[2]
        $arrArea[3] = $arrSubArea[3]
    EndIf
    Local $imgScreen = _OpenCV_GetDesktopScreenMat($arrArea)

    If $imgTempl.empty() Or $imgScreen.empty() Then
        Return False
    EndIf

    If $iActualHeight <> $iBaseClientHeight Then
        Local $fProportion = $iActualHeight / $iBaseClientHeight
        If $arrSubArea <> Default Then
            $arrArea[0] += int($arrSubArea[0] * ($fProportion - 1))
            $arrArea[1] += int($arrSubArea[1] * ($fProportion - 1))
        EndIf
        $arrArea[2] = int($arrArea[2] * $fProportion)
        $arrArea[3] = int($arrArea[3] * $fProportion)
        Local $iAdjWidth = int($imgTempl.width * $fProportion)
        Local $iAdjHeight = int($imgTempl.height * $fProportion)
        $imgTempl = $cv.resize($imgTempl, _OpenCV_Size($iAdjWidth, $iAdjHeight))
    EndIf

    Local $iN = 1

    Local $imgTemplOpt = $cv.cvtColor($imgTempl, $CV_COLOR_BGR2GRAY)
    Local $imgScreenOpt = $cv.cvtColor($imgScreen, $CV_COLOR_BGR2GRAY)
    Local $iTotalCosts = $imgScreen.width * $imgScreen.height * $imgTempl.width * $imgTempl.height
    If $iTotalCosts > 147456000000 Then
        $iN = 2
        $imgTemplOpt = $cv.resize($imgTemplOpt, _OpenCV_Size($imgTempl.width / $iN, $imgTempl.height / $iN))
        $imgScreenOpt = $cv.resize($imgScreenOpt, _OpenCV_Size($imgScreen.width / $iN, $imgScreen.height / $iN))
    EndIf
    Local $matchResults = _OpenCV_FindTemplate($imgScreenOpt, $imgTemplOpt, $fThreshold)  ; Covariant Matrix Normal
    If IsArray($matchResults) And UBound($matchResults) > 0 Then
        Local $arrRect = [$matchResults[0][0] * $iN, $matchResults[0][1] * $iN, $imgTempl.width, $imgTempl.height]
        Return SetError(0, 0, $arrRect)
    Else
        Return SetError(0, 0, False)
    EndIf
EndFunc

; $arrArea is the window area. $arrRect is the subarea relative to the window area.
; When no shifts, default to click the center of the image($subRect). The shifts are relative to the center.
Func ClickRelateWindow($arrArea, $arrRect, $iShiftX = 0, $iShiftY = 0, $bBgClick = False)
    Local $iCenterX = $arrRect[0] + Int($arrRect[2] / 2) + $iShiftX
    Local $iCenterY = $arrRect[1] + Int($arrRect[3] / 2) + $iShiftY
    If $bBgClick Then
        ; Only when this message is accepted, but mostly can't because it's cheat apparently.
        ControlClick($sGameWinTitle, "", "", "left", 1, $iCenterX, $iCenterY)
    Else
        MouseClick("left", $arrArea[0] + $iCenterX, $arrArea[1] + $iCenterY, 1, 0)
    EndIf
EndFunc

; CD: If the image would still be presented for a while after being clicked,
; then if in the next loop the same image is the
; "next" detected, skip it for 1 as the CD unit.
Func ClickImage($sImageFile, $fThreshold = 0.85, $iShiftX = 0, $iShiftY = 0, $bCDOn = False, $iCDMax = 2, $arrSubArea = Default, $iBaseClientHeight = 720)
    Static $sCDImageFile = ""
    Static $iCD = 0

    Local $arrRect = ImageSearch($sImageFile, $fThreshold, $arrSubArea, $iBaseClientHeight)
    If Not IsArray($arrRect) Then
        Return SetError(1, 0, False)
    EndIf

    If $bCDOn And $sCDImageFile = $sImageFile Then
        $iCD += 1
        If $iCD < $iCDMax Then
            Return SetError(0, 0, True)
        Endif
        $iCD = 0
    Else
        $iCD = 0
        $sCDImageFile = $sImageFile
    EndIf

    Local $arrArea = _WinAPI_GetClientPos($sGameWinTitle)
    Local $iActualHeight = $arrArea[3]
    If $arrSubArea <> Default Then
        $arrRect[0] += $arrSubArea[0]
        $arrRect[1] += $arrSubArea[1]
    EndIf

    If $iActualHeight <> $iBaseClientHeight Then
        Local $fProportion = $iActualHeight / $iBaseClientHeight
        If $arrSubArea <> Default Then
            $arrRect[0] += int($arrSubArea[0] * ($fProportion - 1))
            $arrRect[1] += int($arrSubArea[1] * ($fProportion - 1))
        EndIf
        $iShiftX = int($iShiftX * $fProportion)
        $iShiftY = int($iShiftY * $fProportion)
    EndIf

    ClickRelateWindow($arrArea, $arrRect, $iShiftX, $iShiftY)
    Return SetError(0, 0, True)
EndFunc

; Maze Shop Functions
Func MazeShopBuying()
    Local $fDefaultThreshold = 0.80, $fHigherThreshold = 0.90
    Local $bDefaultCDOn = False, $iDefaultCDFactor = 2
    Local $iDelayAnimate = 1500, $iDelayReaction = 150

    Sleep($iDelayReaction)
    If Not $bRunning Then Return True

    While _ScanAndClickBuy("BuyUpgrade.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor)
        Sleep($iDelayAnimate)
        If Not $bRunning Then Return True
    WEnd

    _MazeShopScroll("down")
    Sleep($iDelayReaction)

    While _ScanAndClickBuy("BuyUpgrade.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor)
        Sleep($iDelayAnimate)
        If Not $bRunning Then Return True
    WEnd

    _MazeShopScroll("up")
    Sleep($iDelayReaction)

    Local $bBoughtB = False
    If _ScanAndClickBuy("BuyInvest.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor) Then
        $bBoughtB = True
        Sleep($iDelayReaction)
    EndIf

    _MazeShopScroll("down")
    Sleep($iDelayReaction)

    If _ScanAndClickBuy("BuyInvest.png", $fDefaultThreshold, $bDefaultCDOn, $iDefaultCDFactor) Then
        $bBoughtB = True
        Sleep($iDelayReaction)
    EndIf

    _MazeShopScroll("up")
    Sleep($iDelayReaction)

    If Not $bRunning Then Return True

    Local $areaCurrency = [1060, 70, 161, 41]
    If ClickImage($sGameResDir & "MazeRouge\Txt_ShopMon0.png", $fHigherThreshold, -50, 610, $bDefaultCDOn, $iDefaultCDFactor, $areaCurrency) Then
        Return True
    EndIf
    Return $bBoughtB
EndFunc

Func _ScanAndClickBuy($sImageName, $fThreshold, $bCDOn, $iCDFactor)
    Local $arrMegaShopViewport = [490, 155, 735, 450]
    Local $sFullImagePath = $sGameResDir & "MazeShop\" & $sImageName

    If ClickImage($sFullImagePath, $fThreshold, 0, 0, $bCDOn, $iCDFactor, $arrMegaShopViewport) Then
        Return True
    EndIf

    Return False
EndFunc

Func _MazeShopScroll($sDirection = "down")
    If Not $bRunning Then Return

    Local $arrArea = _WinAPI_GetClientPos($sGameWinTitle)
    If @error Then Return

    Local $iTargetX = $arrArea[0] + Int($arrArea[2] * 0.577)
    Local $iTargetY = $arrArea[1] + Int($arrArea[3] * 0.477)

    MouseMove($iTargetX, $iTargetY, 0)

    If $sDirection = "down" Then
        MouseWheel("down", 5)
    Else
        MouseWheel("up", 5)
    EndIf
EndFunc

Func MazeShopBuyingTypes()
    Local $fDefaultThreshold = 0.85, $bCD = False, $iCDFactor = 2
    Local $aTypes[3][5] = [ _
        ["Type_EN.png",       336, 110, 126, 26], _
        ["Type_Agile.png",    490, 110, 126, 26], _
        ["Type_Phys.png",     184, 110, 126, 26]  _
    ]

    If MazeShopBuying() Then Return True

    For $i = 0 To 2
        Local $arrSubArea = [$aTypes[$i][1], $aTypes[$i][2], $aTypes[$i][3], $aTypes[$i][4]]
        Local $sFullImagePath = $sGameResDir & "MazeShop\" & $aTypes[$i][0]
        ClickImage($sFullImagePath, $fDefaultThreshold, 0, 0, $bCD, $iCDFactor, $arrSubArea)
        If MazeShopBuying() Then Return True
    Next

    Return False
EndFunc

Func MazeShopFarming()
    Local $fDefault = 0.85, $fLow = 0.80, $bCD = False, $iCDFactor = 2, $iDelayReaction = 250

    Local $arrDailyBatchArea = [1095, 110, 126, 26]
    ClickImage($sGameResDir & "MazeShop\Daily_Batch.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrDailyBatchArea)
    Sleep($iDelayReaction)

    Local $aCates[3][5] = [ _
        ["Cate_TypeEquip.png", 19, 302, 126, 26], _
        ["Cate_Excavate.png",  19, 389, 126, 26], _
        ["Cate_Artifact.png",  19, 459, 126, 26]  _
    ]

    For $i = 0 To 2
        Local $arrSubArea = [$aCates[$i][1], $aCates[$i][2], $aCates[$i][3], $aCates[$i][4]]
        Local $sFullImagePath = $sGameResDir & "MazeShop\" & $aCates[$i][0]
        ClickImage($sFullImagePath, $fDefault, 0, 0, $bCD, $iCDFactor, $arrSubArea)
        Local $bStatus = ($i = 1) ? MazeShopBuying() : MazeShopBuyingTypes()
        If $bStatus Then Return
    Next

    _MazeShopAbort($fLow, $bCD, $iCDFactor)
EndFunc

Func _MazeShopAbort($fThreshold, $bCD, $iCDFactor)
    Local $areaShopDoneBtn = [1076, 644, 166, 36]
    ClickImage($sGameResDir & "MazeShop\WB_ShopDone.png", $fThreshold, 0, 0, $bCD, $iCDFactor, $areaShopDoneBtn)
    Local $areaAbortOK = [669, 529, 166, 36]
    Local $iCounter = 0
    While $bRunning And Not ClickImage($sGameResDir & "MazeRouge\RB_OK.png", $fThreshold, 0, 0, $bCD, $iCDFactor, $areaAbortOK)
        Sleep(500)
        If ++$iCounter > 10 Then
            Break
        EndIf
    WEnd
EndFunc

Func MazeNetworkErrored()
    Local $fDefault = 0.85, $bCD = False, $iCDFactor = 2
    Local $iSleep = 2000
    Sleep($iSleep)

    Local $sHomeQuestPath = $sGameResDir & "Com\Bar_Quest.png"
    Local $areaHomeQuest = [730, 674, 81, 21]
    Local $iCounter = 0
    While $bRunning And Not ClickImage($sHomeQuestPath, $fDefault, 0, 0, $bCD, $iCDFactor, $areaHomeQuest)
        Sleep($iSleep)
        If ++$iCounter > 5 Then
            Break
        EndIf
    WEnd

    Sleep($iSleep)

    Local $sHomeMazePath = $sGameResDir & "HomeQuest\Maze.png"
    Local $areaHomeMaze = [1030, 301, 166, 36]
    $iCounter = 0
    While $bRunning And Not ClickImage($sHomeMazePath, $fDefault, 0, 0, $bCD, $iCDFactor, $areaHomeMaze)
        Sleep($iSleep)
        If ++$iCounter > 5 Then
            Break
        EndIf
    WEnd

    Sleep($iSleep)

    Local $sHomeMazeEntryPath = $sGameResDir & "HomeQuest\MazeEntryA.png"
    Local $areaHomeMazeEntryA = [312, 517, 246, 61]
    ClickImage($sHomeMazeEntryPath, $fDefault, 0, 0, $bCD, $iCDFactor, $areaHomeMazeEntryA)
EndFunc

; Log Function
Func WriteLog($msg)
    Local $hFile = FileOpen($sScriptLog, $FO_APPEND + $FO_CREATEPATH)
    If $hFile = -1 Then Return SetError(1, 0, 0)

    FileWriteLine($hFile, StringFormat("%04d-%02d-%02d %02d:%02d:%02d - %s", @YEAR, @MON, @MDAY, @HOUR, @MIN, @SEC, $msg))
    FileClose($hFile)
EndFunc

; Looped Function
Func AutoClick()
    If Not $bRunning Or $bSingleRunning Then Return

    If $bPausing Then
        $iPausingTimer += $iLoopTimer
        If $iPausingTimer >= $iPausingMax Then
            ActionContinue()
        EndIf
        Return
    EndIf

    If Not WinExists($sGameWinTitle) Then
        MsgBox(16, "Error", "Game window not found.")
        ActionStop()
        Return
    EndIf

    Local $aClientSize = WinGetClientSize($sGameWinTitle)
    Local $iWinWDiff = 1280 - $aClientSize[0]
    Local $iWinHDiff = 720 - $aClientSize[1]
    if $iWinWDiff Or $iWinHDiff Then
        Local $aWinSize = WinGetPos($sGameWinTitle)
        WinMove( _
            $sGameWinTitle, "", Default, Default, _
            $aWinSize[2] + $iWinWDiff, _
            $aWinSize[3] + $iWinHDiff _
        )
        GUICtrlSetData($lblStatus, "  Status: Resized ")
    EndIf

    Local $hTimer = $bWriteLogOn ? TimerInit() : 0
    WinActivate($sGameWinTitle)

    Local $fLow = 0.80, $fDefault = 0.85, $fHigh = 0.90
    Local $bCD = False, $iCDFactor = 2
    Local $iPopupDelay = 500

    Local $arrLoadingArea = [595, 325, 91, 66]
    If IsArray(ImageSearch($sGameResDir & "Com\Sys_Loading.png", $fDefault, $arrLoadingArea)) Then
        ActionPause(1500)
        Return
    EndIf

    Local $arrRaidHard = [856, 511, 161, 51]
    ClickImage($sGameResDir & "Com\Raid_Hard.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrRaidHard)

    Local $arrRB = [960, 510, 320, 210]
    If ClickImage($sGameResDir & "MazeRouge\RB_Start.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrRB) Or _
       ClickImage($sGameResDir & "MazeRouge\RB_Route.png", $fLow - 0.05, 0, 0, $bCD, $iCDFactor, $arrRB) Or _
       ClickImage($sGameResDir & "Quest\RB_Enter.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrRB) Then
        ActionPause(2500)
        Return
    EndIf

    Local $aSingleClicks[8] = [ _
        "MazeRouge\RB_Enter.png", "MazeRouge\WB_Leave.png", "MazeRouge\RB_Decide.png", _
        "Quest\RB_Scene.png", "Com\RB_Ready.png", "Com\RB_Raid.png", _
        "Com\RB_Sally.png", "Com\RB_Next.png" _
    ]
    For $img In $aSingleClicks
        ClickImage($sGameResDir & $img, $fDefault, 0, 0, $bCD, $iCDFactor, $arrRB)
    Next

    Local $arrRU = [960, 0, 320, 210]
    If ClickImage($sGameResDir & "Com\Sys_Menu.png", $fDefault, -560, 370, $bCD, $iCDFactor, $arrRU) Then
        If $bMazeFarmingOn Then
            $bSingleRunning = True
            MazeNetworkErrored()
            $bSingleRunning = False
        EndIf
        Return
    EndIf
    ClickImage($sGameResDir & "Com\BB_SkipA.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrRU)
    ClickImage($sGameResDir & "Com\BB_SkipB.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrRU)
    ClickImage($sGameResDir & "Com\BB_SkipC.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrRU)
    ClickImage($sGameResDir & "MazeRouge\Txt_ShopMon0.png", $fHigh, -50, 610, $bCD, $iCDFactor, $arrRU)

    Local $arrGachaTitleArea = [104, 21, 86, 26]
    ClickImage($sGameResDir & "Com\Txt_Gacha.png", $fDefault, -90, 0, $bCD, $iCDFactor, $arrGachaTitleArea)

    Local $arrXDw = [300, 380, 680, 210]  ; Down
    ClickImage($sGameResDir & "Com\WB_Close.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrXDw)
    ClickImage($sGameResDir & "Com\RB_Title.png", $fLow, 0, 0, $bCD, $iCDFactor, $arrXDw)
    ClickImage($sGameResDir & "MazeRouge\RB_OK.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrXDw)

    Local $arrM1 = [576, 141, 126, 26]
    ClickImage($sGameResDir & "MazeRouge\Txt_SelRelic.png", $fDefault, 0, 150, $bCD, $iCDFactor, $arrM1)

    Local $arrEvOptArea = [1144, 324, 115, 375]
    Local $arrCraftDoneArea = [905, 636, 126, 26]
    ClickImage($sGameResDir & "MazeRouge\Txt_EvOpt.png", $fDefault, -50, -25, $bCD, $iCDFactor, $arrEvOptArea)

    If $bMazeCraftSkip Then
        If ClickImage($sGameResDir & "MazeRouge\WB_CraftDone.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrCraftDoneArea) Then
            Sleep($iPopupDelay)
            ClickImage($sGameResDir & "MazeRouge\RB_OK.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrXDw)
        EndIf
    EndIf

    If IsArray(ImageSearch($sGameResDir & "Com\WB_TryAgain.png", $fDefault, $arrRB)) Then
        ActionStop()
        GUICtrlSetData($lblStatus, "  Battle: Failed  ")
        Return
    EndIf
    If IsArray(ImageSearch($sGameResDir & "Com\Txt_Limited.png", $fHigh + 0.05, $arrRB)) Then
        ActionStop()
        GUICtrlSetData($lblStatus, " Activity: Limited")
        Return
    EndIf
    If IsArray(ImageSearch($sGameResDir & "Quest\RB_Clear.png", $fDefault, $arrRB)) Then
        ActionStop()
        GUICtrlSetData($lblStatus, "  Quest: Clear    ")
        Return
    EndIf
    If IsArray(ImageSearch($sGameResDir & "Com\BB_Menu.png", $fDefault, $arrRU)) Then
        ActionStop()
        GUICtrlSetData($lblStatus, "  Status: InADV   ")
        Return
    EndIf

    Local $arrShopDoneCancelArea = [444, 529, 166, 36]
    If $bMazeFarmingOn Then
        ClickImage($sGameResDir & "MazeShop\WB_Cancel.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrShopDoneCancelArea)
    EndIf
    Local $iTimerReaction = 500
    Local $arrDailyUnitArea = [644, 110, 126, 26]
    If ClickImage($sGameResDir & "MazeShop\Daily_Unit.png", $fDefault, 0, 0, $bCD, $iCDFactor, $arrDailyUnitArea) Then
        $bSingleRunning = True
        Sleep($iTimerReaction)
        If Not $bRunning Then
            $bSingleRunning = False
            Return
        EndIf

        Local $arrDailyClearArea = [263, 586, 126, 26]
        If IsArray(ImageSearch($sGameResDir & "MazeShop\Daily_Clear.png", $fLow, $arrDailyClearArea)) Then
            If $bMazeFarmingOn Then
                MazeShopFarming()
            Else
                _MazeShopAbort($fLow, $bCD, $iCDFactor)
            EndIf
        EndIf
        $bSingleRunning = False
    EndIf

    If $bWriteLogOn Then
        WriteLog("AutoClick: " & TimerDiff($hTimer) & " ms")
    EndIf
EndFunc

; Internal Handling
Func _OnAutoItExit()
    _GDIPlus_Shutdown()
    _OpenCV_Close()
EndFunc
