package net.benboeckel.abagames.gunroar;

import org.libsdl.app.SDLActivity;
import android.content.pm.ActivityInfo;
import android.os.Bundle;

public class GunroarActivity extends SDLActivity
{
    @Override
    protected String[] getLibraries() {
        return new String[] {
            "SDL2",
            "SDL2_mixer",
            "main"
        };
    }

    @Override String[] getArguments() {
        // Get the default window size.
        Context context = SDLActivity.getContext();
        WindowManager wm = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
        Display display = wm.getDefaultDisplay();
        Point size = new Point();
        display.getSize(size);

        return new String[] {
            "-res",
            Integer.toString(size.x),
            Integer.toString(size.y)
        };
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
    }
}
