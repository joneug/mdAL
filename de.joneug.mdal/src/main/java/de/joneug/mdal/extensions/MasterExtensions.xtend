package de.joneug.mdal.extensions

import de.joneug.mdal.generator.GeneratorManagement
import de.joneug.mdal.mdal.Entity
import de.joneug.mdal.mdal.Master
import de.joneug.mdal.mdal.TemplateAddress
import de.joneug.mdal.mdal.TemplateDimensions
import de.joneug.mdal.mdal.TemplateSalesperson

import static extension de.joneug.mdal.extensions.DocumentExtensions.*
import static extension de.joneug.mdal.extensions.DocumentHeaderExtensions.*
import static extension de.joneug.mdal.extensions.EObjectExtensions.*
import static extension de.joneug.mdal.extensions.EntityExtensions.*
import static extension de.joneug.mdal.extensions.PageFieldExtensions.*
import static extension de.joneug.mdal.extensions.SolutionExtensions.*
import static extension de.joneug.mdal.extensions.StringExtensions.*

/**
 * This is an extension library for all {@link Master objects}.
 */
class MasterExtensions {

	static GeneratorManagement management = GeneratorManagement.getInstance()
	
	static def getDataCaptionFields(Master master) {
		val fields = (master as Entity).dataCaptionFields
		fields.add('No.')
		return fields
	}
	
	static def getFieldgroupDropDown(Master master) {
		val fields = (master as Entity).fieldgroupDropDown
		fields.add('No.')
		return fields
	}
	
	static def getFieldGroupBrick(Master master) {
		val fields = (master as Entity).fieldGroupBrick
		fields.add('No.')
		return fields
	}
	
	static def void doGenerate(Master master) {
		master.saveTable(master.tableName, master.doGenerateTable)
		master.savePage(master.cardPageName, master.doGenerateCardPage)
		master.savePage(master.listPageName, master.doGenerateListPage)
	}

	static def doGenerateTable(Master master) '''
		«val solution = master.solution»
		«val document = solution.document»
		table «management.getNewTableNo(master)» «master.tableName.saveQuote»
		{
			Caption = '«master.name»';
			DataCaptionFields = «FOR field : master.dataCaptionFields SEPARATOR ', '»«field.saveQuote»«ENDFOR»;
			DrillDownPageID = "«master.listPageName»";
			LookupPageId = "«master.listPageName»";
			
			fields
			{
				field(«management.getNewFieldNo(master)»; "No."; Code[20])
				{
					Caption = 'No.';
					
					trigger OnValidate()
					begin
						if "No." <> xRec."No." then begin
							Get«solution.setupTableVariableName»();
							NoSeriesMgt.TestManual(«solution.setupTableVariableName»."«master.name» Nos.");
							"No. Series" := '';
						end;
					end;
				}
				«master.doGenerateTableFields»
				field(«management.getNewFieldNo(master)»; Blocked; Boolean)
				{
					Caption = 'Blocked';
				}
				field(«management.getNewFieldNo(master)»; "Last Date Modified"; Date)
				{
					Caption = 'Last Date Modified';
					Editable = false;
				}
				field(«management.getNewFieldNo(master)»; "No. Series"; Code[20])
				{
					Caption = 'No. Series';
					Editable = false;
					TableRelation = "No. Series";
				}
				field(«management.getNewFieldNo(master)»; Comment; Boolean)
				{
					CalcFormula = Exist ("Comment Line" where("Table Name" = const(«master.name.saveQuote»), "No." = field("No.")));
					Caption = 'Comment';
					Editable = false;
					FieldClass = FlowField;
				}
			}
			
			keys
			{
				key(Key«management.getNewKeyNo(master)»; "No.")
				{
					Clustered = true;
				}
				«FOR field : master.keys»
					key(Key«management.getNewKeyNo(master)»; «field.saveQuote») { }
				«ENDFOR»
			}
			
			fieldgroups
			{
				fieldgroup(DropDown; «FOR field : master.fieldgroupDropDown SEPARATOR ', '»«field.saveQuote»«ENDFOR») { }
				fieldgroup(Brick; «FOR field : master.fieldGroupBrick SEPARATOR ', '»«field.saveQuote»«ENDFOR») { }
			}
			
			trigger OnInsert()
			begin
				if "No." = '' then begin
					Test«master.cleanedName»NoSeries();
					NoSeriesMgt.InitSeries(«solution.setupTableVariableName»."«master.name» Nos.", xRec."No. Series", 0D, "No.", "No. Series");
				end;
				
				«IF master.hasTemplateOfType(TemplateDimensions)»
					DimMgt.UpdateDefaultDim(Database::"«master.tableName»", "No.", "Global Dimension 1 Code", "Global Dimension 2 Code");
				«ENDIF»
			end;
			
			trigger OnModify()
			begin
				"Last Date Modified" := Today;
			end;
			
			trigger OnDelete()
			begin
				«IF master.hasTemplateOfType(TemplateDimensions)»
					DimMgt.DeleteDefaultDim(Database::"«master.tableName»", "No.");
					
				«ENDIF»
				CommentLine.SetRange("Table Name", CommentLine."Table Name"::«master.name.saveQuote»);
				CommentLine.SetRange("No.", "No.");
				CommentLine.DeleteAll();
				
				«IF document !== null»
					«document.header.tableVariableName».SetCurrentKey("«master.cleanedName» No.");
					«document.header.tableVariableName».SetRange("«master.cleanedName» No.", "No.");
					IF NOT «document.header.tableVariableName».IsEmpty THEN
						Error(
							ExistingDocumentsErr,
							TableCaption, "No.", «document.header.tableVariableName».TableCaption);
				«ENDIF»
			end;
			
			trigger OnRename()
			begin
				"Last Date Modified" := Today;
			end;
				
			var
				«solution.setupTableVariableName»Read: Boolean;
				«solution.setupTableVariableName»: Record "«solution.setupTableName»";
				NoSeriesMgt: Codeunit NoSeriesManagement;
				CommentLine: Record "Comment Line";
				«master.tableVariableName»: Record "«master.tableName»";
				«IF document !== null»
					«document.header.tableVariableName»: Record "«document.header.tableName»";
					ExistingDocumentsErr: Label 'You cannot delete %1 %2 because there is at least one outstanding %3 for this «master.name».';
				«ENDIF»
				«IF master.hasTemplateOfType(TemplateDimensions)»
					DimMgt: Codeunit DimensionManagement;
				«ENDIF»
				«IF master.hasTemplateOfType(TemplateAddress)»
					PostCode: Record "Post Code";
		        «ENDIF»
				
			procedure AssistEdit(Old«master.tableVariableName»: Record "«master.tableName»"): Boolean
			begin
				«master.tableVariableName» := Rec;
				Test«master.cleanedName»NoSeries();
				if NoSeriesMgt.SelectSeries(«solution.setupTableVariableName»."«master.name» Nos.", Old«master.tableVariableName»."No. Series", «master.tableVariableName»."No. Series") then begin
					Test«master.cleanedName»NoSeries();
					NoSeriesMgt.SetSeries(«master.tableVariableName»."No.");
					Rec := «master.tableVariableName»;
					exit(true);
				end;
			end;
			
			«IF master.hasTemplateOfType(TemplateDimensions)»
				procedure ValidateShortcutDimCode(FieldNumber: Integer; var ShortcutDimCode: Code[20])
				begin
					OnBeforeValidateShortcutDimCode(Rec, xRec, FieldNumber, ShortcutDimCode);
					
					DimMgt.ValidateDimValueCode(FieldNumber, ShortcutDimCode);
					if not IsTemporary then begin
						DimMgt.SaveDefaultDim(Database::"«master.tableName»", "No.", FieldNumber, ShortcutDimCode);
						Modify;
					end;
					
					OnAfterValidateShortcutDimCode(Rec, xRec, FieldNumber, ShortcutDimCode);
				end;
				
				[IntegrationEvent(false, false)]
				local procedure OnBeforeValidateShortcutDimCode(var «master.tableVariableName»: Record "«master.tableName»"; var x«master.tableVariableName»: Record "«master.tableName»"; FieldNumber: Integer; var ShortcutDimCode: Code[20])
				begin
				end;
				
				[IntegrationEvent(false, false)]
				local procedure OnAfterValidateShortcutDimCode(var «master.tableVariableName»: Record "«master.tableName»"; var x«master.tableVariableName»: Record "«master.tableName»"; FieldNumber: Integer; var ShortcutDimCode: Code[20])
				begin
				end;
				
			«ENDIF»
			local procedure Get«solution.setupTableVariableName»()
			begin
				if not «solution.setupTableVariableName»Read then
					«solution.setupTableVariableName».Get();
					
				«solution.setupTableVariableName»Read := true;
				
				OnAfterGet«solution.setupTableVariableName»(«solution.setupTableVariableName»);
			end;
			
			[IntegrationEvent(false, false)]
			local procedure OnAfterGet«solution.setupTableVariableName»(var «solution.setupTableVariableName»: Record "«solution.setupTableName»")
			begin
			end;
			
			local procedure Test«master.cleanedName»NoSeries()
			begin
				Get«solution.setupTableVariableName»();
				«solution.setupTableVariableName».TestField("«master.name» Nos.");
			end;
			
			procedure TestBlocked()
			begin
				TestField(Blocked, false);
			end;
			«IF master.hasTemplateOfType(TemplateSalesperson)»
				
				local procedure ValidateSalesPersonCode()
				var
					SalespersonPurchaser: Record "Salesperson/Purchaser";
				begin
					if "Salesperson Code" <> '' then
						if SalespersonPurchaser.Get("Salesperson Code") then
							if SalespersonPurchaser.VerifySalesPersonPurchaserPrivacyBlocked(SalespersonPurchaser) then
								Error(SalespersonPurchaser.GetPrivacyBlockedGenericText(SalespersonPurchaser, true));
				end;
			«ENDIF»
			«IF master.hasTemplateOfType(TemplateAddress)»
				
				[IntegrationEvent(false, false)]
				local procedure OnBeforeLookupCity(«master.tableVariableName»: Record «master.tableName.saveQuote»; var PostCodeRec: Record "Post Code");
				begin
				end;
				
				[IntegrationEvent(false, false)]
				local procedure OnBeforeLookupPostCode(«master.tableVariableName»: Record «master.tableName.saveQuote»; var PostCodeRec: Record "Post Code");
				begin
				end;
				
				[IntegrationEvent(false, false)]
				local procedure OnBeforeValidateCity(«master.tableVariableName»: Record «master.tableName.saveQuote»; var PostCodeRec: Record "Post Code");
				begin
				end;
				
				[IntegrationEvent(false, false)]
				local procedure OnBeforeValidatePostCode(«master.tableVariableName»: Record «master.tableName.saveQuote»; var PostCodeRec: Record "Post Code");
				begin
				end;
			«ENDIF»
		}
	'''
	
	static def doGenerateCardPage(Master master) '''
		«val document = master.solution.document»
		page «management.newPageNo» «master.cardPageName.saveQuote»
		{
		    Caption = '«master.name» Card';
		    PageType = Card;
		    PromotedActionCategories = 'New,Process,Report,New Document,«master.name»,Navigate';
		    RefreshOnActivate = true;
		    SourceTable = «master.tableName.saveQuote»;
		
		    layout
		    {
		        area(content)
		        {
		        	group(General)
		        	{
		        		Caption = 'General';
		        		
		        		field("No."; Rec."No.")
		                {
		                    ApplicationArea = All;
		                    Importance = Standard;
		
		                    trigger OnAssistEdit()
		                    begin
		                        if AssistEdit(xRec) then
		                            CurrPage.Update;
		                    end;
		                }
		                «FOR pageField : master.getPageFieldsInGroup('General')»
		                	«pageField.doGenerate»
		                «ENDFOR»
		                field(Blocked; Rec.Blocked)
		                {
		                    ApplicationArea = All;
		                }
		                field(LastDateModified; Rec."Last Date Modified")
		                {
		                    ApplicationArea = All;
		                    Importance = Additional;
		                }
		        	}
		        	«FOR group : master.cardPageGroups.filter[it.name != 'General']»
		        		group(«group.name.saveQuote»)
		        		{
		        			Caption = '«group.name»';
		        			
		        			«FOR pageField : group.pageFields»
		        				«pageField.doGenerate»
		        			«ENDFOR»
		        		}
		        	«ENDFOR»
		        }
		        area(factboxes)
		        {
		        	«IF master.hasTemplateOfType(TemplateDimensions)»
		        	part(Control1905532107; "Dimensions FactBox")
		        	{
		        		ApplicationArea = All;
		        		SubPageLink = "Table ID" = const(«management.getTableNo(master)»),
		        					  "No." = field("No.");
		        	}
		        	«ENDIF»
		            systempart(Control1900383207; Links)
		            {
		                ApplicationArea = RecordLinks;
		            }
		            systempart(Control1905767507; Notes)
		            {
		                ApplicationArea = Notes;
		            }
		        }
		    }
		
		    actions
		    {
		        area(navigation)
		        {
		            group("&«master.name»")
		            {
		                Caption = '&«master.name»';
		                «IF master.hasTemplateOfType(TemplateDimensions)»
		                action(Dimensions)
		                {
		                    ApplicationArea = Dimensions;
		                    Caption = 'Dimensions';
		                    Image = Dimensions;
		                    Promoted = true;
		                    PromotedCategory = Category5;
		                    PromotedIsBig = true;
		                    RunObject = Page "Default Dimensions";
		                    RunPageLink = "Table ID" = CONST(«management.getTableNo(master)»),
		                                  "No." = FIELD("No.");
		                    ShortCutKey = 'Alt+D';
		                    ToolTip = 'View or edit dimensions, such as area, project, or department, that you can assign to sales and purchase documents to distribute costs and analyze transaction history.';
		                }
		                «ENDIF»
		                action("Co&mments")
		                {
		                    ApplicationArea = Comments;
		                    Caption = 'Co&mments';
		                    Image = ViewComments;
		                    Promoted = true;
		                    PromotedCategory = Category6;
		                    RunObject = Page "Comment Sheet";
		                    RunPageLink = "Table Name" = const(«master.name.saveQuote»),
		                                  "No." = field("No.");
		                    ToolTip = 'View or add comments for the record.';
		                }
		            }
		        }
		        «IF document !== null»
		        	area(creation)
		        	{
		        		action(New«document.cleanedName»)
		        		{
		        			AccessByPermission = tabledata «document.header.tableName.saveQuote» = RIM;
		        			ApplicationArea = All;
		        			Caption = '«document.name»';
		        			Image = NewDocument;
		        			Promoted = true;
		        			PromotedCategory = Category4;
		        			RunObject = Page «document.documentPageName.saveQuote»;
		        			RunPageLink = "«master.name» No." = field("No.");
		        			RunPageMode = Create;
		        			Visible = NOT IsOfficeAddin;
		        		}
		        	}
		        «ENDIF»
		    }
		
		    var
		        IsOfficeAddin: Boolean;
		
		    local procedure ActivateFields()
		    var
		        OfficeManagement: Codeunit "Office Management";
		    begin
		        IsOfficeAddin := OfficeManagement.IsAvailable;
		    end;
		}
	'''
	
	static def doGenerateListPage(Master master) '''
	page «management.newPageNo» «master.listPageName.saveQuote»
	{
	    ApplicationArea = All;
	    Caption = '«master.name»s';
	    CardPageID = «master.cardPageName.saveQuote»;
	    Editable = false;
	    PageType = List;
	    PromotedActionCategories = 'New,Process,Report,«master.name»,Navigate';
	    SourceTable = «master.tableName.saveQuote»;
	    UsageCategory = Lists;
	
	    layout
	    {
	        area(content)
	        {
	            repeater(Control1)
	            {
	                field("No."; "No.")
	                {
	                    ApplicationArea = All;
	                }
	                «FOR pageField : master.listPageFields»
	                	«pageField.doGenerate»
	                «ENDFOR»
	                field(Blocked; Blocked)
	                {
	                    ApplicationArea = All;
	                    Visible = false;
	                }
	            }
	        }
	        area(factboxes)
	        {
	            systempart(Control1900383207; Links)
	            {
	                ApplicationArea = RecordLinks;
	                Visible = false;
	            }
	            systempart(Control1905767507; Notes)
	            {
	                ApplicationArea = Notes;
	                Visible = true;
	            }
	        }
	    }
	
	    actions
	    {
	        area(navigation)
	        {
	            group("&«master.name»")
	            {
	                Caption = '&«master.name»';
	                action("Co&mments")
	                {
	                    ApplicationArea = Comments;
	                    Caption = 'Co&mments';
	                    Image = ViewComments;
	                    Promoted = true;
	                    PromotedCategory = Category4;
	                    RunObject = Page "Comment Sheet";
	                    RunPageLink = "Table Name" = const(«master.name.saveQuote»),
	                                  "No." = field("No.");
	                    ToolTip = 'View or add comments for the record.';
	                }
	            }
	        }
	    }
	}
	'''

}
