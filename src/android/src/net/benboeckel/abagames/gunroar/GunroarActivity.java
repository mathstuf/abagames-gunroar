package net.benboeckel.abagames.gunroar;

import org.libsdl.app.SDLActivity;

public class GunroarActivity extends SDLActivity
{
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
    }
}
