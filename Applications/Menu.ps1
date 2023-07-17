function GenerateForm {

[reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
[reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null

$form1 = New-Object System.Windows.Forms.Form
$button1 = New-Object System.Windows.Forms.Button
$listBox1 = New-Object System.Windows.Forms.ListBox

# Teamviewer 9 (var3.10)
$checkBox22 = New-Object System.Windows.Forms.CheckBox

# TCC Fasttrack (var3.9)
$checkBox21 = New-Object System.Windows.Forms.CheckBox

# Officeathandmeeting (var3.8)
$checkBox20 = New-Object System.Windows.Forms.CheckBox

# Officeathand (var3.7)
$checkBox19 = New-Object System.Windows.Forms.CheckBox

# Correctek Spark (var3.6)
$checkBox18 = New-Object System.Windows.Forms.CheckBox

# Office 2019 Installer (var3.5)
$checkBox17 = New-Object System.Windows.Forms.CheckBox

# Desktop Background Information (var3.4)
$checkBox16 = New-Object System.Windows.Forms.CheckBox

# Add to Domain 
$checkBox15 = New-Object System.Windows.Forms.CheckBox

$checkBox14 = New-Object System.Windows.Forms.CheckBox
$checkBox13 = New-Object System.Windows.Forms.CheckBox
$checkBox12 = New-Object System.Windows.Forms.CheckBox
$checkBox11 = New-Object System.Windows.Forms.CheckBox
$checkBox10 = New-Object System.Windows.Forms.CheckBox
$checkBox9 = New-Object System.Windows.Forms.CheckBox
$checkBox8 = New-Object System.Windows.Forms.CheckBox
$checkBox7 = New-Object System.Windows.Forms.CheckBox
$checkBox6 = New-Object System.Windows.Forms.CheckBox
$checkBox5 = New-Object System.Windows.Forms.CheckBox
$checkBox4 = New-Object System.Windows.Forms.CheckBox
$checkBox3 = New-Object System.Windows.Forms.CheckBox
$checkBox2 = New-Object System.Windows.Forms.CheckBox
$checkBox1 = New-Object System.Windows.Forms.CheckBox
$InitialFormWindowState = New-Object System.Windows.Forms.FormWindowState

$b1= $false
$b2= $false
$b3= $false

#----------------------------------------------
#Generated Event Script Blocks
#----------------------------------------------

$handler_button1_Click= 
{
    $listBox1.Items.Clear();    

    if ($checkBox1.Checked)     {  $listBox1.Items.Add( "Will Run Configuration Script"  )
    "set var1=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No Configuration Script"  )
    "set var1=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    if ($checkBox2.Checked)    {  $listBox1.Items.Add( "Will Configure NTP"  ) 
    "set var2=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No NTP Configuration"  )
    "set var2=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    if ($checkBox3.Checked)    {  $listBox1.Items.Add( "Enabling RDP"  ) 
    "set var3=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No RDP Configuration"  )
    "set var3=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }
    
    if ($checkBox4.Checked)    {  $listBox1.Items.Add( "Installing Adobe Reader"  ) 
    "set var4=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No Adobe Reader"  )
    "set var4=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    if ($checkBox5.Checked)    {  $listBox1.Items.Add( "Installing NetExtender"  ) 
    "set var5=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No NetExtender"  )
    "set var5=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    if ($checkBox6.Checked)    {  $listBox1.Items.Add( "Install Chrome"  ) 
    "set var2.1=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No Chrome Install"  )
    "set var2.1=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    if ($checkBox7.Checked)    {  $listBox1.Items.Add( "Install Agent"  ) 
    "set var2.2=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else { $listBox1.Items.Add( "No Agent" )
    "set var2.2=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    if ($checkBox8.Checked)    {  $listBox1.Items.Add( "Patching Enabled"  ) 
    "set var2.3=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
    "set var2.4=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "Will not Patch"  )
    "set var2.3=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
    "set var2.4=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    if ($checkBox9.Checked)    {  $listBox1.Items.Add( "Installing Teams"  ) 
    "set var3.1=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No Teams"  )
    "set var3.1=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     } 

    if ($checkBox10.Checked)    {  $listBox1.Items.Add( "Installing FireFox"  ) 
    "set var3.2=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No FireFox"  )
    "set var3.2=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     } 

    if ($checkBox11.Checked)    {  $listBox1.Items.Add( "Installing Office 365"  ) 
    "set var3.3=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No Office 365"  )
    "set var3.3=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     } 

    if ($checkBox12.Checked)    {  $listBox1.Items.Add( "Changing Default Apps"  ) 
    "set var4.1=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No Default App Change"  )
    "set var4.1=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }  

    if ($checkBox13.Checked)    {  $listBox1.Items.Add( "Changing Visual Settings"  ) 
    "set var4.2=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No Visual Setting Changes"  )
    "set var4.2=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     } 

    if ($checkBox14.Checked)    {  $listBox1.Items.Add( "Changing nwadmin Password"  ) 
    "set var5.1=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
    $nwpass = Read-Host "Please Enter nwadmin password"
    "set var5.11=$nwpass" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No nwadmin password change"  )
    "set var5.1=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     } 

    if ($checkBox15.Checked)    {  $listBox1.Items.Add( "Adding to Domain"  ) 
    "set var5.2=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
    $domainadd = Read-Host "Please Enter Domain"
    "set var5.21=$domainadd" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No nwadmin password change"  )
    "set var5.2=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     } 

    if ($checkBox16.Checked)    {  $listBox1.Items.Add( "Installing Desktop Background Information"  ) 
    "set var3.4=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No Desktop Background Information"  )
    "set var3.4=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    if ($checkBox17.Checked)    {  $listBox1.Items.Add( "Running Office 2019 Installer"  ) 
    "set var3.5=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No Office 2019 Installer"  )
    "set var3.5=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    if ($checkBox18.Checked)    {  $listBox1.Items.Add( "Installing Correctek Spark"  ) 
    "set var3.6=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No Correctek Spark"  )
    "set var3.6=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    if ($checkBox19.Checked)    {  $listBox1.Items.Add( "Installing Office at Hand"  ) 
    "set var3.7=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No Office at Hand"  )
    "set var3.7=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    if ($checkBox20.Checked)    {  $listBox1.Items.Add( "Installing Office at Hand Meeting"  ) 
    "set var3.8=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No Office at Hand Meeting"  )
    "set var3.8=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    if ($checkBox21.Checked)    {  $listBox1.Items.Add( "Installing TCC Fasttrack"  ) 
    "set var3.9=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No TCC Fasttrack"  )
    "set var3.9=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    if ($checkBox22.Checked)    {  $listBox1.Items.Add( "Installing Teamviewer 9"  ) 
    "set var3.10=yes" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }

    else   {  $listBox1.Items.Add( "No Teamviewer 9"  )
    "set var3.10=no" | Out-File -append -Encoding ascii -FilePath "C:\Users\$env:UserName\Desktop\Applications\variables.bat"
     }



    if ( !$checkBox1.Checked -and !$checkBox2.Checked -and !$checkBox3.Checked ) {   $listBox1.Items.Add("No CheckBox selected....")} 

start-process -FilePath C:\Users\$env:UserName\Desktop\Applications\Stepstart.bat

}

$OnLoadForm_StateCorrection=
{#Correct the initial state of the form to prevent the .Net maximized form issue
    $form1.WindowState = $InitialFormWindowState
}

#----------------------------------------------
#region Generated Form Code
$form1.Text = "Primal Form"
$form1.Name = "form1"
$form1.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 800
$System_Drawing_Size.Height = 800
$form1.ClientSize = $System_Drawing_Size

$button1.TabIndex = 4
$button1.Name = "button1"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 75
$System_Drawing_Size.Height = 23
$button1.Size = $System_Drawing_Size
$button1.UseVisualStyleBackColor = $True

$button1.Text = "Run Script"

$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 695
$button1.Location = $System_Drawing_Point
$button1.DataBindings.DefaultDataSourceUpdateMode = 0
$button1.add_Click($handler_button1_Click)

$form1.Controls.Add($button1)

$listBox1.FormattingEnabled = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 301
$System_Drawing_Size.Height = 450
$listBox1.Size = $System_Drawing_Size
$listBox1.DataBindings.DefaultDataSourceUpdateMode = 0
$listBox1.Name = "listBox1"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 137
$System_Drawing_Point.Y = 13
$listBox1.Location = $System_Drawing_Point
$listBox1.TabIndex = 3

$form1.Controls.Add($listBox1)

$checkBox22.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox22.Size = $System_Drawing_Size
$checkBox22.TabIndex = 2
$checkBox22.Text = "Teamviewer 9"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 664
$checkBox22.Location = $System_Drawing_Point
$checkBox22.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox22.Name = "checkBox22"

$form1.Controls.Add($checkBox22)

$checkBox21.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox21.Size = $System_Drawing_Size
$checkBox21.TabIndex = 2
$checkBox21.Text = "TCC Fasttrack"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 633
$checkBox21.Location = $System_Drawing_Point
$checkBox21.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox21.Name = "checkBox21"

$form1.Controls.Add($checkBox21)

$checkBox20.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox20.Size = $System_Drawing_Size
$checkBox20.TabIndex = 2
$checkBox20.Text = "Office at Hand Meeting"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 602
$checkBox20.Location = $System_Drawing_Point
$checkBox20.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox20.Name = "checkBox20"

$form1.Controls.Add($checkBox20)

$checkBox19.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox19.Size = $System_Drawing_Size
$checkBox19.TabIndex = 2
$checkBox19.Text = "Office at Hand"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 571
$checkBox19.Location = $System_Drawing_Point
$checkBox19.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox19.Name = "checkBox19"

$form1.Controls.Add($checkBox19)

$checkBox18.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox18.Size = $System_Drawing_Size
$checkBox18.TabIndex = 2
$checkBox18.Text = "Correctek Spark"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 540
$checkBox18.Location = $System_Drawing_Point
$checkBox18.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox18.Name = "checkBox18"

$form1.Controls.Add($checkBox18)

$checkBox17.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox17.Size = $System_Drawing_Size
$checkBox17.TabIndex = 2
$checkBox17.Text = "Office 2019"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 509
$checkBox17.Location = $System_Drawing_Point
$checkBox17.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox17.Name = "checkBox17"

$form1.Controls.Add($checkBox17)

$checkBox16.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox16.Size = $System_Drawing_Size
$checkBox16.TabIndex = 2
$checkBox16.Text = "Install BGInfo"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 478
$checkBox16.Location = $System_Drawing_Point
$checkBox16.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox16.Name = "checkBox16"

$form1.Controls.Add($checkBox16)

$checkBox15.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox15.Size = $System_Drawing_Size
$checkBox15.TabIndex = 2
$checkBox15.Text = "Add to Domain"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 447
$checkBox15.Location = $System_Drawing_Point
$checkBox15.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox15.Name = "checkBox15"

$form1.Controls.Add($checkBox15)

$checkBox14.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox14.Size = $System_Drawing_Size
$checkBox14.TabIndex = 2
$checkBox14.Text = "nwadmin password"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 416
$checkBox14.Location = $System_Drawing_Point
$checkBox14.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox14.Name = "checkBox14"

$form1.Controls.Add($checkBox14)

$checkBox13.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox13.Size = $System_Drawing_Size
$checkBox13.TabIndex = 2
$checkBox13.Text = "Change Visual Settings"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 385
$checkBox13.Location = $System_Drawing_Point
$checkBox13.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox13.Name = "checkBox13"

$form1.Controls.Add($checkBox13)

$checkBox12.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox12.Size = $System_Drawing_Size
$checkBox12.TabIndex = 2
$checkBox12.Text = "Change Default Apps"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 354
$checkBox12.Location = $System_Drawing_Point
$checkBox12.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox12.Name = "checkBox12"

$form1.Controls.Add($checkBox12)

$checkBox11.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox11.Size = $System_Drawing_Size
$checkBox11.TabIndex = 2
$checkBox11.Text = "Install O365"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 323
$checkBox11.Location = $System_Drawing_Point
$checkBox11.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox11.Name = "checkBox11"

$form1.Controls.Add($checkBox11)

$checkBox10.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox10.Size = $System_Drawing_Size
$checkBox10.TabIndex = 2
$checkBox10.Text = "Install Firefox"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 292
$checkBox10.Location = $System_Drawing_Point
$checkBox10.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox10.Name = "checkBox10"

$form1.Controls.Add($checkBox10)

$checkBox9.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox9.Size = $System_Drawing_Size
$checkBox9.TabIndex = 2
$checkBox9.Text = "Install Teams"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 261
$checkBox9.Location = $System_Drawing_Point
$checkBox9.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox9.Name = "checkBox9"

$form1.Controls.Add($checkBox9)

$checkBox8.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox8.Size = $System_Drawing_Size
$checkBox8.TabIndex = 2
$checkBox8.Text = "Windows Patching"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 230
$checkBox8.Location = $System_Drawing_Point
$checkBox8.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox8.Name = "checkBox8"

$form1.Controls.Add($checkBox8)

$checkBox7.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox7.Size = $System_Drawing_Size
$checkBox7.TabIndex = 2
$checkBox7.Text = "Install Chrome"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 199
$checkBox7.Location = $System_Drawing_Point
$checkBox7.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox7.Name = "checkBox7"

$form1.Controls.Add($checkBox7)

$checkBox6.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox6.Size = $System_Drawing_Size
$checkBox6.TabIndex = 2
$checkBox6.Text = "Install Agent"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 168
$checkBox6.Location = $System_Drawing_Point
$checkBox6.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox6.Name = "checkBox6"

$form1.Controls.Add($checkBox6)

$checkBox5.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox5.Size = $System_Drawing_Size
$checkBox5.TabIndex = 2
$checkBox5.Text = "Install NetExtender"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 137
$checkBox5.Location = $System_Drawing_Point
$checkBox5.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox5.Name = "checkBox5"

$form1.Controls.Add($checkBox5)

$checkBox4.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox4.Size = $System_Drawing_Size
$checkBox4.TabIndex = 2
$checkBox4.Text = "Install Adobe Reader"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 106
$checkBox4.Location = $System_Drawing_Point
$checkBox4.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox4.Name = "checkBox4"

$form1.Controls.Add($checkBox4)


$checkBox3.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox3.Size = $System_Drawing_Size
$checkBox3.TabIndex = 2
$checkBox3.Text = "Enable RDP"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 75
$checkBox3.Location = $System_Drawing_Point
$checkBox3.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox3.Name = "checkBox3"

$form1.Controls.Add($checkBox3)


$checkBox2.UseVisualStyleBackColor = $True
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Width = 104
$System_Drawing_Size.Height = 34
$checkBox2.Size = $System_Drawing_Size
$checkBox2.TabIndex = 1
$checkBox2.Text = "NTP Configuration"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 27
$System_Drawing_Point.Y = 44
$checkBox2.Location = $System_Drawing_Point
$checkBox2.DataBindings.DefaultDataSourceUpdateMode = 0
$checkBox2.Name = "checkBox2"

$form1.Controls.Add($checkBox2)



    $checkBox1.UseVisualStyleBackColor = $True
    $System_Drawing_Size = New-Object System.Drawing.Size
    $System_Drawing_Size.Width = 104
    $System_Drawing_Size.Height = 34
    $checkBox1.Size = $System_Drawing_Size
    $checkBox1.TabIndex = 0
    $checkBox1.Text = "Basic Computer Configuration"
    $System_Drawing_Point = New-Object System.Drawing.Point
    $System_Drawing_Point.X = 27
    $System_Drawing_Point.Y = 13
    $checkBox1.Location = $System_Drawing_Point
    $checkBox1.DataBindings.DefaultDataSourceUpdateMode = 0
    $checkBox1.Name = "checkBox1"

$form1.Controls.Add($checkBox1)


#Save the initial state of the form
$InitialFormWindowState = $form1.WindowState
#Init the OnLoad event to correct the initial state of the form
$form1.add_Load($OnLoadForm_StateCorrection)
#Show the Form
$form1.ShowDialog()| Out-Null

} #End Function

#Call the Function
GenerateForm