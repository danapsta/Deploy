# Function to generate the form
function GenerateForm {

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Form creation
    $form1 = New-Object System.Windows.Forms.Form
    $form1.Text = 'Automation Script'
    $form1.Size = New-Object System.Drawing.Size(250,800)
    $form1.StartPosition = 'CenterScreen'
    
    # FlowLayoutPanel creation
    $flowLayoutPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $flowLayoutPanel.Dock = [System.Windows.Forms.DockStyle]::Fill

    # CheckBoxes
    $checkBoxTexts = @('Basic Computer Configuration', 'NTP Configuration', 'Enable RDP', 'Install Adobe Reader',
                       'Install NetExtender', 'Install Agent', 'Install Chrome', 'Windows Patching', 'Install Teams',
                       'Install Firefox', 'Install O365', 'Change Default Apps', 'Change Visual Settings', 
                       'nwadmin password', 'Add to Domain', 'Install BGInfo', 'Office 2019', 'Correctek Spark',
                       'Office at Hand')

    for ($i = 0; $i -lt $checkBoxTexts.Length; $i++) {
        $checkBox = New-Object System.Windows.Forms.CheckBox
        $checkBox.Size = New-Object System.Drawing.Size(200, 20)
        $checkBox.Text = $checkBoxTexts[$i]
        $checkBox.Name = "checkBox$($i + 1)"
        $checkBox.UseVisualStyleBackColor = $True
        $flowLayoutPanel.Controls.Add($checkBox)
    }

    # Button creation
    $runButton = New-Object System.Windows.Forms.Button
    $runButton.Location = New-Object System.Drawing.Point(75, 600)
    $runButton.Size = New-Object System.Drawing.Size(100, 23)
    $runButton.Text = 'Run Script'
    $runButton.add_Click({RunScript})
    $flowLayoutPanel.Controls.Add($runButton)

    # Adding the FlowLayoutPanel to the form
    $form1.Controls.Add($flowLayoutPanel)

    # Show the form
    $form1.ShowDialog()| Out-Null
} 

# Call the function
GenerateForm
