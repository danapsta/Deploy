$checkBoxList = @{
    checkBox1 = @{
        Message = 'Configuration Script'
        Var = 'var1'
        SpecialAction = {
            $newname = Read-Host "Please Enter New Computer Name"
            $newname | Out-File -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\Default\newname"
        }
    }
    checkBox2 = @{
        Message = 'NTP Configuration'
        Var = 'var2'
    }
    #... continue for all checkboxes, same as previous examples
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Script Execution'
$form.Size = New-Object System.Drawing.Size(300,300)
$form.StartPosition = 'CenterScreen'

$button1 = New-Object System.Windows.Forms.Button
$button1.Location = New-Object System.Drawing.Point(75,120)
$button1.Size = New-Object System.Drawing.Size(75,23)
$button1.Text = 'Run Script'
$button1.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $button1
$form.Controls.Add($button1)

$listBox1 = New-Object System.Windows.Forms.ListBox
$listBox1.Location = New-Object System.Drawing.Point(10,20)
$listBox1.Size = New-Object System.Drawing.Size(260,90)
$listBox1.Height = 200
$form.Controls.Add($listBox1)

$button1.Add_Click({
    $listBox1.Items.Clear() 
    $batFile = "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
    
    foreach($key in $checkBoxList.Keys) {
        $checkBox = $form.Controls[$key]
        $settings = $checkBoxList[$key]

        $message = if ($checkBox.Checked) {
            "Will Run $($settings.Message)"
        } else {
            "No $($settings.Message)"
        }

        $listBox1.Items.Add($message)

        "set $($settings.Var)=$($checkBox.Checked)" | Out-File -append -Encoding ascii -FilePath $batFile

        if ($checkBox.Checked -and $settings.SpecialAction) {
            & $settings.SpecialAction
        }
    }

    if (!(($form.Controls|? Checked).Count)) {
        $listBox1.Items.Add("No CheckBox selected....")
    }

    Start-Process -FilePath "C:\Users\$env:UserName\Desktop\Applications\Stepstart.bat"
})

$form.ShowDialog()
