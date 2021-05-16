fdescribe('getPrimaryServices', function () {
  "use strict";
  afterAll(clearNextAction);

  it('should return some primary services', async () => {
    setNextAction();

    const puck = await getConnectedPuck('Select a puck (so we can get primary services)');
    expect(puck).toBeDefined();

    const servs = await puck.gatt.getPrimaryServices();

    expect(servs.length).toBeGreaterThan(0);
  }, 60000);
});
