/*
 * $Id: prefmanager.d,v 1.1.1.1 2005/06/18 00:46:00 kenta Exp $
 *
 * Copyright 2004 Kenta Cho. Some rights reserved.
 */
module abagames.util.prefmanager;

/**
 * Save/load the preference(e.g. high-score).
 */
public interface PrefManager {
  public void save();
  public void load();
}
