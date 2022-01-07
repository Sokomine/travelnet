
# Changelog

09.12.21 - Added ability to rename stations
10.03.19 - Added the extra config buttons for locked_travelnet mod.
09.03.19 - Several PRs merged (sound added, locale changed etc.)
					 Version bumped to 2.3
26.02.19 - Removing a travelnet can now be done by clicking on a button (no need to
					 wield a diamond pick anymore)
26.02.19 - Added compatibility with MineClone2
22.09.18 - Move up/move down no longer close the formspec.
22.09.18 - If in creative mode, wield a diamond pick to dig the station. This avoids
					 conflicts with too fast punches.
24.12.17 - Added support for localization through intllib.
					 Added localization for German (de).
					 Door opening/closing can now handle more general doors.
17.07.17 - Added more detailled licence information.
					 TNT and DungeonMasters ought to leave travelnets and elevators untouched now.
					 Added function to register elevator doors.
					 Added elevator doors made out of tin ingots.
					 Provide information about the nearest elevator network when placing a new elevator. This
						 ought to make it easier to find the right spot.
					 Improved formspec.
16.07.17 - Merged several PR from others (Typo, screenshot, documentation, mesecon support, bugfix).
					 Added buttons to move stations up or down in the list, independent on when they where added.
					 Fixed undeclared globals.
					 Changed deprecated functions set_look_yaw/pitch to current functions.
22.07.17 - Fixed bug with locked travelnets beeing removed from the network due to not beeing recognized.
30.08.16 - If the station the traveller just travelled to no longer exists, the player is sent back to the
					 station where he/she came from.
30.08.16 - Attaching a travelnet box to a non-existant network of another player is possible (requested by OldCoder).
					 Still requires the travelnet_attach-priv.
05.10.14 - Added an optional abm so that the travelnet network can heal itshelf in case of loss of the savefile.
					 If you want to use this, set
								 travelnet.enable_abm = true
					 in config.lua and edit the interval in the abm to suit your needs.
19.11.13 - moved doors and travelnet definition into an extra file
				 - moved configuration to config.lua
05.08.13 - fixed possible crash when the node in front of the travelnet is unknown
26.06.13 - added inventory image for elevator (created by VanessaE)
21.06.13 - bugfix: wielding an elevator while digging a door caused the elevator_top to be placed
				 - leftover floating elevator_top nodes can be removed by placing a new
					 travelnet:elevator underneath them and removing that afterwards
				 - homedecor-doors are now opened and closed correctly as well
				 - removed nodes that are not intended for manual use from creative inventory
				 - improved naming of station levels for the elevator
21.06.13 - elevator stations are sorted by height instead of date of creation as is the case with travelnet boxes
				 - elevator stations are named automaticly
20.06.13 - doors can be opened and closed from inside the travelnet box/elevator
				 - the elevator can only move vertically; the network name is defined by its x and z coordinate
13.06.13 - bugfix
				 - elevator added (written by kpoppel) and placed into extra file
				 - elevator doors added
				 - groups changed to avoid accidental dig/drop on dig of node beneath
				 - added new priv travelnet_remove for digging of boxes owned by other players
				 - only the owner of a box or players with the travelnet_remove priv can now dig it
				 - entering your own name as owner_name does no longer abort setup
22.03.13 - added automatic detection if yaw can be set
				 - beam effect is disabled by default
20.03.13 - added inventory image provided by VanessaE
				 - fixed bug that made it impossible to remove stations from the net
				 - if the station a player beamed to no longer exists, the station will be removed automaticly
				 - with the travelnet_attach priv, you can now attach your box to the nets of other players
				 - in newer versions of Minetest, the players yaw is set so that he/she looks out of the receiving box
				 - target list is now centered if there are less than 9 targets

