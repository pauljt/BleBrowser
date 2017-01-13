# 1.0 test cases

## Selecting devices from greenparksoftware.co.uk

1. request device when one in range. Cancel. Turn off device. Request again. Should not appear in menu.
  - ok 1
2. request device when no devices in range. "Done" should be disabled, "Cancel" should cancel. 
  - ok 1
3. request device, see device appear, turn off device, device should disappear... 
  - na 1, replace with 4.
4. request device, see device appear, turn off device and select it before it has a chance to disappear.
  - ok 1, behaviour is that we should attempt to connect, but that it will continue attempting even if device doesn't come back
5. connect to a device, send a command, turn off device, request new device should be clear of that old device
  - fail 1, it wasn't clear, but came clear after cancelling and trying again.
6. select device after it has been switched off. Cancel connection attempt. Request, no device shown.


## Browser controls

1. Forward / back greyed out when nowhere to go
  - ok 1
2. Back and forward work when not greyed out
  - ok 1
3. refresh works after successful navigation
  - ok 1
4. refresh works after failed navigation (to reattempt the page)
  - ok 1
5. address bar show current full URL
  - ok 1
6. on failed navigation, address bar shows URL of location we attempted to navigate to.
  - ok 1

# 1.1 test cases

1. requestDevice, see popup come up, then navigate to a different page. popup should go away.
